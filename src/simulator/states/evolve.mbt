///|
/// Execute unitary kernels. Terminal measurements leave the returned state unchanged.
/// The first wire is the most significant basis digit.
pub fn evolve(program : @circuit.Program) -> StateVector raise @error.QError {
  // This path skips measurements and never draws random values.
  let state = StateVectorState::new(program.dim(), seed=0UL)
  let mut measuring = false
  for instruction in program.instructions(expand_loops=true) {
    guard instruction is Operation(op) && op.effect().try_conditional() is None else {
      raise @error.InvalidCondition(
        "evolve cannot evaluate measurement conditions",
      )
    }
    check_instruction(instruction)
    if op.effect().measurement_key() is Some(_) {
      measuring = true
    } else {
      if measuring {
        raise @error.QError::InvalidState(
          "evolve requires terminal measurements",
        )
      }
      execute_gate(state.vector, state.strides, op.effect(), op.targets())
    }
  }
  state.validate()
  state.vector
}

///|
/// Check the unitary capability and target shape before applying a gate.
fn execute_gate(
  state : StateVector,
  strides : Array[Int32],
  effect : &@circuit.Effect,
  targets : Array[Int32],
) -> Unit raise @error.QError {
  let gate = checked_unitary(effect, targets, state.shape)
  apply_local(state.re, state.im, state.shape, strides, gate.kernel(), targets)
}

///|
fn checked_unitary(
  effect : &@circuit.Effect,
  targets : Array[Int32],
  shape : @internal.Shape,
) -> @circuit.Gate raise @error.QError {
  guard effect.try_unitary() is Some(gate) else {
    raise @error.QError::InvalidGate("unsupported effect: " + effect.name())
  }

  let gate_shape = gate.shape()
  if gate_shape.length() != targets.length() {
    raise @error.QError::TargetCount(targets.length(), gate_shape.length())
  }

  for i, target in targets {
    if gate_shape[i] != shape[target] {
      raise @error.QError::DimensionMismatch(i, shape[target], gate_shape[i])
    }
  }
  gate
}

///|
fn validate_norm(state : StateVector) -> Unit raise @error.QError {
  let norm = state.norm_squared()
  if norm.is_nan() || norm.is_inf() || (norm - 1.0).abs() > 1.0e-6 {
    raise @error.QError::InvalidState("kernel output must have unit norm")
  }
}

///|
/// Map local basis indices to offsets in the full state.
fn local_offsets(
  shape : @internal.Shape,
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
  shape : @internal.Shape,
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
  shape : @internal.Shape,
  strides : Array[Int32],
  kernel : &@circuit.LinearKernel,
  targets : Array[Int32],
  conjugate~ : Bool = false,
) -> Unit {
  let local_size = kernel.size()
  let offsets = local_offsets(shape, strides, targets, local_size)
  let input_re = Array::make(local_size, 0.0)
  let input_im = Array::make(local_size, 0.0)
  let output_re = Array::make(local_size, 0.0)
  let output_im = Array::make(local_size, 0.0)
  for base in 0..<re.length() {
    if !is_local_base(base, shape, strides, targets) {
      continue
    }
    for j in 0..<local_size {
      input_re[j] = re[base + offsets[j]]
      input_im[j] = if conjugate {
        -im[base + offsets[j]]
      } else {
        im[base + offsets[j]]
      }
    }
    kernel.apply({
      input_re: input_re[:],
      input_im: input_im[:],
      output_re: output_re.mut_view(),
      output_im: output_im.mut_view(),
    })
    for j in 0..<local_size {
      re[base + offsets[j]] = output_re[j]
      im[base + offsets[j]] = if conjugate {
        -output_im[j]
      } else {
        output_im[j]
      }
    }
  }
}
