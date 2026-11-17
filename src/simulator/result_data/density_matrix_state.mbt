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
/// Unitary instructions evolve the density matrix according to:
///   ρ' = U ρ U†
pub fn DensityMatrixState::apply(
  self : DensityMatrixState,
  instruction : @circuit.Instruction,
) -> Unit raise @error.QError {
  if check_instruction(instruction) {
    self.validate()
    self.measure(instruction.targets())
    return
  }
  let targets = instruction.targets()
  let gate = checked_unitary(instruction.effect(), targets, self.matrix.shape)
  apply_local(
    self.matrix.re,
    self.matrix.im,
    self.tensor_shape,
    self.tensor_strides,
    gate.kernel(),
    targets,
  )
  // Applying the conjugate kernel to column digits gives right multiplication by U-adjoint.
  let columns = targets.map(wire => wire + self.matrix.shape.length())
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
  _self : DensityMatrixState,
  _targets : Array[Int32],
) -> Unit raise @error.QError {
  // TODO
  raise @error.InvalidState("TODO")
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
