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
  instruction : @circuit.Instruction[Int32],
) -> Unit raise @error.QError {
  check_instruction(instruction)
  guard self.base.dispatch(instruction, child => self.apply(child))
    is Some((effect, targets)) else {
    return
  }
  if effect.measurement_key() is Some(name) {
    self.validate()
    self.measure(targets, name)
  } else {
    execute_gate(self.vector, self.strides, effect, targets)
  }
}

///|
fn StateVectorState::measure(
  self : StateVectorState,
  targets : Array[Int32],
  key : String,
) -> Unit raise @error.QError {
  let probabilities = self.vector.marginal_probabilities(targets)
  let outcome = measurement_outcome(probabilities, self.base.draw())
  let digits = measurement_digits(self.vector.shape, targets, outcome)
  self.collapse_measurement(targets, digits, probabilities[outcome])
  self.base.record(digits[:], key~)
}

///|
/// Keep amplitudes matching the measured digits and divide by sqrt(probability).
fn StateVectorState::collapse_measurement(
  self : StateVectorState,
  targets : Array[Int32],
  digits : Array[Int32],
  probability : Double,
) -> Unit {
  let scale = 1.0 / probability.sqrt()
  for basis in 0..<self.vector.re.length() {
    if self.matches_digits(basis, targets, digits) {
      self.vector.re[basis] *= scale
      self.vector.im[basis] *= scale
    } else {
      self.vector.re[basis] = 0.0
      self.vector.im[basis] = 0.0
    }
  }
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
