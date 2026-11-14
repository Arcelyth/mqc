///|
/// Execute unitary kernels. Terminal measurements leave the returned state unchanged.
/// The first wire is the most significant basis digit.
pub fn evolve(
  program : @circuit.Program,
) -> StateVector raise @circuit.QuantumError {
  let state = StateVector::zero(program.dimensions())
  let strides = wire_strides(state.shape)
  execute_instructions(state, strides, program)
  validate_norm(state)
  state
}

///|
/// Compute the basis stride of each wire, from last to first.
fn wire_strides(shape : Array[UInt32]) -> Array[Int32] {
  let strides = Array::make(shape.length(), 1)
  let mut stride = 1
  for i = shape.length() - 1; i >= 0; i = i - 1 {
    strides[i] = stride
    stride *= shape[i].reinterpret_as_int()
  }
  strides
}

///|
/// Apply instructions in order and check terminal measurement rules.
fn execute_instructions(
  state : StateVector,
  strides : Array[Int32],
  program : @circuit.Program,
) -> Unit raise @circuit.QuantumError {
  let mut measuring = false
  let keys : Map[String, Bool] = Map([])
  for instruction in program.instructions() {
    let effect = instruction.effect()
    if effect.parameters().length() != 0 {
      raise @circuit.InvalidState("TODO: unbound parameters are not supported")
    }
    if effect.measurement_key() is Some(key) {
      if keys.contains(key) {
        raise @circuit.InvalidState("measurement keys must be unique")
      }
      keys[key] = true
      measuring = true
      continue
    }

    if measuring {
      raise @circuit.InvalidState("only terminal measurements are supported")
    }
    execute_gate(state, strides, instruction)
  }
}

///|
/// Check the unitary capability and target shape before applying a gate.
fn execute_gate(
  state : StateVector,
  strides : Array[Int32],
  instruction : @circuit.Instruction,
) -> Unit raise @circuit.QuantumError {
  let effect = instruction.effect()
  guard effect.try_unitary() is Some(gate) else {
    raise @circuit.InvalidGate("unsupported effect: " + effect.name())
  }

  let targets = instruction.targets()
  let gate_shape = gate.dimensions()
  if gate_shape.length() != targets.length() {
    raise @circuit.TargetCount(targets.length(), gate_shape.length())
  }

  for i, target in targets {
    if gate_shape[i] != state.shape[target] {
      raise @circuit.DimensionMismatch(i, state.shape[target], gate_shape[i])
    }
  }
  apply_local(state.re, state.im, state.shape, strides, gate, targets)
}

///|
fn validate_norm(state : StateVector) -> Unit raise @circuit.QuantumError {
  let norm = state.norm_squared()
  if norm.is_nan() || norm.is_inf() || (norm - 1.0).abs() > 1.0e-6 {
    raise @circuit.InvalidState("kernel output must have unit norm")
  }
}

///|
/// Map local basis indices to offsets in the full state.
fn local_offsets(
  shape : Array[UInt32],
  strides : Array[Int32],
  targets : Array[Int32],
  local_size : Int32,
) -> Array[Int32] {
  Array::makei(local_size, fn(index) {
    let mut digit_index = index
    let mut offset = 0
    for i = targets.length() - 1; i >= 0; i = i - 1 {
      let wire = targets[i]
      let radix = shape[wire].reinterpret_as_int()
      offset += digit_index % radix * strides[wire]
      digit_index /= radix
    }
    offset
  })
}

///|
/// A local block starts where all target digits are zero.
fn is_local_base(
  base : Int32,
  shape : Array[UInt32],
  strides : Array[Int32],
  targets : Array[Int32],
) -> Bool {
  for wire in targets {
    if base / strides[wire] % shape[wire].reinterpret_as_int() != 0 {
      return false
    }
  }
  true
}

///|
fn apply_local(
  re : Array[Double],
  im : Array[Double],
  shape : Array[UInt32],
  strides : Array[Int32],
  gate : @circuit.Gate,
  targets : Array[Int32],
) -> Unit {
  let local_size = gate.dimension()
  let offsets = local_offsets(shape, strides, targets, local_size)
  let input_re = Array::make(local_size, 0.0)
  let input_im = Array::make(local_size, 0.0)
  let output_re = Array::make(local_size, 0.0)
  let output_im = Array::make(local_size, 0.0)
  let kernel = gate.kernel()
  for base in 0..<re.length() {
    if !is_local_base(base, shape, strides, targets) {
      continue
    }
    for j in 0..<local_size {
      input_re[j] = re[base + offsets[j]]
      input_im[j] = im[base + offsets[j]]
    }
    kernel.apply({
      input_re: input_re[:],
      input_im: input_im[:],
      output_re: output_re.mut_view(),
      output_im: output_im.mut_view(),
    })
    for j in 0..<local_size {
      re[base + offsets[j]] = output_re[j]
      im[base + offsets[j]] = output_im[j]
    }
  }
}
