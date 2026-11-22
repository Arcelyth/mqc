///|
/// Mutable density-matrix execution data.
struct DensityMatrixState {
  base : SimulationStateBase
  /// Current density matrix.
  matrix : DensityMatrix
  /// Row wire dimensions followed by column wire dimensions.
  tensor_shape : @internal.Shape
  /// Steps between adjacent wire digits in the flattened matrix.
  tensor_strides : Array[Int32]
}

///|
fn density_state(matrix : DensityMatrix, seed : UInt64?) -> DensityMatrixState {
  let dimensions = matrix.dim()
  let doubled = dimensions.copy()
  for dimension in dimensions {
    doubled.push(dimension)
  }
  let tensor_shape = @internal.Shape::new(doubled)
  {
    base: SimulationStateBase::new(seed?),
    matrix,
    tensor_shape,
    tensor_strides: tensor_shape.strides(),
  }
}

///|
pub fn DensityMatrixState::new(
  dimensions : Array[UInt32],
  seed? : UInt64,
) -> DensityMatrixState raise @error.QError {
  density_state(DensityMatrix::zero(dimensions), seed)
}

///|
pub fn DensityMatrixState::from_density(
  matrix : DensityMatrix,
  seed? : UInt64,
) -> DensityMatrixState raise @error.QError {
  validate_density(matrix)
  density_state(matrix.copy(), seed)
}

///|
pub fn DensityMatrixState::dim(self : DensityMatrixState) -> Array[UInt32] {
  self.matrix.dim()
}

///|
pub fn DensityMatrixState::copy(
  self : DensityMatrixState,
) -> DensityMatrixState {
  {
    base: self.base.copy(),
    matrix: self.matrix.copy(),
    tensor_shape: self.tensor_shape,
    tensor_strides: self.tensor_strides,
  }
}

///|
/// Export a density matrix that later execution cannot mutate.
pub fn DensityMatrixState::density_matrix(
  self : DensityMatrixState,
) -> DensityMatrix {
  self.matrix.copy()
}

///|
pub fn DensityMatrixState::probabilities(
  self : DensityMatrixState,
) -> Array[Double] {
  self.matrix.probabilities()
}

///|
pub fn DensityMatrixState::records(
  self : DensityMatrixState,
) -> @maths.Array3[Int32] {
  self.base.records()
}

///|
pub fn DensityMatrixState::validate(
  self : DensityMatrixState,
) -> Unit raise @error.QError {
  validate_density(self.matrix)
}

///|
/// Apply a quantum instruction to the density-matrix state.
///
/// Measurement instructions are handled separately by validating the
/// current state and measuring the requested target wires.
///
/// A channel sums the contributions of its Kraus operators on the target
/// wires. Only explicit measurements append digits to the shot record.
pub fn DensityMatrixState::apply(
  self : DensityMatrixState,
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
    return
  }
  let columns = targets.map(wire => wire + self.matrix.shape.length())
  if effect.try_channel() is Some(channel) {
    check_target_shape(channel.shape(), targets, self.matrix.shape)
    apply_local(
      self.matrix.re,
      self.matrix.im,
      self.tensor_shape,
      self.tensor_strides,
      @qinfo.kraus_map(channel),
      targets + columns,
    )
    return
  }
  let gate = checked_unitary(effect, targets, self.matrix.shape)
  apply_local(
    self.matrix.re,
    self.matrix.im,
    self.tensor_shape,
    self.tensor_strides,
    gate.kernel(),
    targets,
  )
  // Applying the conjugate kernel to column digits gives right multiplication by U-adjoint.
  apply_local(
    self.matrix.re,
    self.matrix.im,
    self.tensor_shape,
    self.tensor_strides,
    gate.kernel(),
    columns,
    conjugate=true,
  )
}

///|
fn DensityMatrixState::measure(
  self : DensityMatrixState,
  targets : Array[Int32],
  key : String,
) -> Unit raise @error.QError {
  let probabilities = self.matrix.marginal_probabilities(targets)
  let outcome = measurement_outcome(probabilities, self.base.draw())
  self.collapse_measurement(targets, outcome, probabilities[outcome])
  let digits = measurement_digits(self.matrix.shape, targets, outcome)
  self.base.record(digits[:], key~)
}

///|
/// Keep both matrix indices in the measured subspace, then divide by its probability.
fn DensityMatrixState::collapse_measurement(
  self : DensityMatrixState,
  targets : Array[Int32],
  outcome : Int32,
  probability : Double,
) -> Unit {
  let size = self.matrix.size()
  let keep = Array::makei(size, basis => {
    self.measurement_index(basis, targets) == outcome
  })
  for row in 0..<size {
    for column in 0..<size {
      let index = row * size + column
      if keep[row] && keep[column] {
        self.matrix.re[index] /= probability
        self.matrix.im[index] /= probability
      } else {
        self.matrix.re[index] = 0.0
        self.matrix.im[index] = 0.0
      }
    }
  }
}

///|
/// Pack target digits in their measurement order, using the cached column strides.
fn DensityMatrixState::measurement_index(
  self : DensityMatrixState,
  basis : Int32,
  targets : Array[Int32],
) -> Int32 {
  let wires = self.matrix.shape.length()
  let mut index = 0
  for wire in targets {
    let dimension = self.matrix.shape[wire].reinterpret_as_int()
    index = index * dimension +
      basis / self.tensor_strides[wires + wire] % dimension
  }
  index
}

///|
/// Physical constructors check positivity. Evolution checks finite entries, trace, and symmetry.
fn validate_density(matrix : DensityMatrix) -> Unit raise @error.QError {
  let size = matrix.size()
  let trace = matrix.trace()
  if trace.is_nan() || trace.is_inf() || (trace - 1.0).abs() > 1.0e-6 {
    raise @error.InvalidState("density matrix must have unit trace")
  }
  for row in 0..<size {
    if matrix.re[row * size + row] < -1.0e-10 {
      raise @error.InvalidState("density matrix has a negative probability")
    }
    for column in 0..<size {
      let index = row * size + column
      let other = column * size + row
      let value = @maths.Complex::new(matrix.re[index], matrix.im[index])
      if !value.is_finite() ||
        (value.re - matrix.re[other]).abs() > 1.0e-6 ||
        (value.im + matrix.im[other]).abs() > 1.0e-6 {
        raise @error.InvalidState("density matrix must be finite and Hermitian")
      }
    }
  }
}
