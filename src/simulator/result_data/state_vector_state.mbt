///|
/// Mutable state-vector execution data.
struct StateVectorState {
  base : SimulationStateBase
  vector : StateVector
  strides : Array[Int32]
}

///|
pub fn StateVectorState::new(
  dimensions : Array[UInt32],
  seed? : UInt64,
) -> StateVectorState {
  let vector = StateVector::zero(dimensions)
  {
    base: SimulationStateBase::new(seed?),
    vector,
    strides: vector.shape.strides(),
  }
}

///|
pub fn StateVectorState::from_state(
  state : StateVector,
  seed? : UInt64,
) -> StateVectorState raise @error.QError {
  validate_norm(state)
  {
    base: SimulationStateBase::new(seed?),
    vector: { shape: state.shape, re: state.re.copy(), im: state.im.copy(), },
    strides: state.shape.strides(),
  }
}

///|
pub fn StateVectorState::dim(self : StateVectorState) -> Array[UInt32] {
  self.vector.dim()
}

///|
pub fn StateVectorState::copy(self : StateVectorState) -> StateVectorState {
  let vector = self.vector
  {
    base: self.base.copy(),
    vector: { shape: vector.shape, re: vector.re.copy(), im: vector.im.copy(), },
    strides: self.strides,
  }
}

///|
/// Export a state vector that later execution cannot mutate.
pub fn StateVectorState::statevector(self : StateVectorState) -> StateVector {
  {
    shape: self.vector.shape,
    re: self.vector.re.copy(),
    im: self.vector.im.copy(),
  }
}

///|
pub fn StateVectorState::records(
  self : StateVectorState,
) -> @maths.Array3[Int32] {
  self.base.records()
}

///|
pub fn StateVectorState::validate(
  self : StateVectorState,
) -> Unit raise @error.QError {
  validate_norm(self.vector)
}

///|
/// Execute one instruction and change this state in place.
pub fn StateVectorState::apply(
  self : StateVectorState,
  instruction : @circuit.Instruction,
) -> Unit raise @error.QError {
  if check_instruction(instruction) {
    self.validate()
    self.measure(instruction.targets(), self.base.draw())
  } else {
    execute_gate(self.vector, self.strides, instruction)
  }
}

///|
fn StateVectorState::measure(
  self : StateVectorState,
  targets : Array[Int32],
  draw : Double,
) -> Unit raise @error.QError {
  let probabilities = self.vector.probabilities()
  let mut total = 0.0
  for probability in probabilities {
    total += probability
  }
  let threshold = draw * total
  let mut cumulative = 0.0
  let mut basis = probabilities.length() - 1
  for i, probability in probabilities {
    cumulative += probability
    if threshold < cumulative {
      basis = i
      break
    }
  }
  let digits = targets.map(fn(wire) {
    basis / self.strides[wire] % self.vector.shape[wire].reinterpret_as_int()
  })
  let mut probability = 0.0
  for i, weight in probabilities {
    if self.matches_digits(i, targets, digits) {
      probability += weight
    }
  }
  if probability <= 0.0 || probability.is_nan() || probability.is_inf() {
    raise @error.QError::InvalidState("invalid measurement probability")
  }
  let scale = 1.0 / probability.sqrt()
  for i in 0..<probabilities.length() {
    if self.matches_digits(i, targets, digits) {
      self.vector.re[i] *= scale
      self.vector.im[i] *= scale
    } else {
      self.vector.re[i] = 0.0
      self.vector.im[i] = 0.0
    }
  }
  self.base.record(digits[:])
}

///|
fn StateVectorState::matches_digits(
  self : StateVectorState,
  basis : Int32,
  targets : Array[Int32],
  digits : Array[Int32],
) -> Bool {
  for i, wire in targets {
    if basis / self.strides[wire] % self.vector.shape[wire].reinterpret_as_int() !=
      digits[i] {
      return false
    }
  }
  true
}
