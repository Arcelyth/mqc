///|
/// Mutable state-vector execution data.
struct StateVectorState {
  base : SimulationStateBase
  vector : StateVector
  strides : Array[Int32]
  keys : Map[String, Bool]
  mut measuring : Bool
}

///|
pub fn StateVectorState::new(
  shape : Array[UInt32],
  seed? : UInt64,
) -> StateVectorState raise @circuit.QuantumError {
  let vector = StateVector::zero(shape)
  {
    base: SimulationStateBase::new(seed?),
    vector,
    strides: wire_strides(vector.shape),
    keys: Map([]),
    measuring: false,
  }
}

///|
pub fn StateVectorState::copy(self : StateVectorState) -> StateVectorState {
  let vector = self.vector
  {
    base: self.base.copy(),
    vector: { shape: vector.shape, re: vector.re.copy(), im: vector.im.copy(), },
    strides: self.strides,
    keys: self.keys.copy(),
    measuring: self.measuring,
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
) -> Unit raise @circuit.QuantumError {
  validate_norm(self.vector)
}

///|
/// Execute one instruction and change this state in place.
pub fn StateVectorState::apply(
  self : StateVectorState,
  instruction : @circuit.Instruction,
) -> Unit raise @circuit.QuantumError {
  if self.check_instruction(instruction) {
    self.validate()
    self.measure(instruction.targets(), self.base.draw())
  } else {
    execute_gate(self.vector, self.strides, instruction)
  }
}

///|
/// Validate execution order and return whether this instruction is a measurement.
fn StateVectorState::check_instruction(
  self : StateVectorState,
  instruction : @circuit.Instruction,
) -> Bool raise @circuit.QuantumError {
  let effect = instruction.effect()
  if effect.parameters().length() != 0 {
    raise @circuit.InvalidState("unbound parameters are not supported")
  }
  if effect.measurement_key() is Some(key) {
    if self.keys.contains(key) {
      raise @circuit.InvalidState("measurement keys must be unique")
    }
    self.keys[key] = true
    self.measuring = true
    true
  } else {
    if self.measuring {
      raise @circuit.InvalidState("only terminal measurements are supported")
    }
    false
  }
}

///|
fn StateVectorState::measure(
  self : StateVectorState,
  targets : Array[Int32],
  draw : Double,
) -> Unit raise @circuit.QuantumError {
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
    raise @circuit.InvalidState("invalid measurement probability")
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
