///|
/// A quantum state represented by a complex density matrix.
///
/// For example, a two-qubit state |ψ> = (|00> + |11>) / √2:
///
///   shape = [2, 2]
///   re    = [1/2, 0, 0, 1/2,
///              0, 0, 0,   0,
///              0, 0, 0,   0,
///            1/2, 0, 0, 1/2]
///   im    = [0, 0, 0, 0,
///            0, 0, 0, 0,
///            0, 0, 0, 0,
///            0, 0, 0, 0]
///
/// Rows and columns follow basis-state order: |00>, |01>, |10>, |11>.
/// Entries are stored one row after another, at row * size + column.
struct DensityMatrix {
  shape : @internal.Shape
  re : Array[Double]
  im : Array[Double]
}

///|
/// Check representable dimensions and entry count before allocating a matrix.
fn density_size(shape : @internal.Shape) -> Int32 raise @error.QError {
  let mut size = 1
  for i in 0..<shape.length() {
    let dimension = shape[i]
    if dimension == 0U {
      raise @error.InvalidDimension(dimension)
    }
    if dimension > (2147483647 / size).reinterpret_as_uint() {
      raise @error.SizeLimit(2147483647)
    }
    size *= dimension.reinterpret_as_int()
  }
  if size > 2147483647 / size {
    raise @error.SizeLimit(2147483647)
  }
  size
}

///|
fn empty_density(shape : @internal.Shape) -> DensityMatrix raise @error.QError {
  let size = density_size(shape)
  {
    shape,
    re: Array::make(size * size, 0.0),
    im: Array::make(size * size, 0.0),
  }
}

///|
pub fn DensityMatrix::zero(
  dimensions : Array[UInt32],
) -> DensityMatrix raise @error.QError {
  DensityMatrix::basis(dimensions, 0)
}

///|
pub fn DensityMatrix::basis(
  dimensions : Array[UInt32],
  index : Int32,
) -> DensityMatrix raise @error.QError {
  let shape = @internal.Shape::new(dimensions)
  let size = density_size(shape)
  if index < 0 || index >= size {
    raise @error.InvalidBasis(index)
  }
  let matrix = empty_density(shape)
  matrix.re[index * size + index] = 1.0
  matrix
}

///|
/// Given a normalized state vector, constructs its density
/// matrix by computing the outer product:
pub fn DensityMatrix::from_state(
  state : StateVector,
) -> DensityMatrix raise @error.QError {
  validate_norm(state)
  let matrix = empty_density(state.shape)
  matrix.add_pure(state, 1.0)
  matrix.complete_hermitian()
  matrix
}

///|
/// Mix pure states with finite, nonnegative weights that sum to one.
/// All states must have the same ordered wire dimensions. Inputs are copied.
pub fn DensityMatrix::from_mixture(
  states : Array[StateVector],
  weights : Array[Double],
) -> DensityMatrix raise @error.QError {
  if states.is_empty() || states.length() != weights.length() {
    raise @error.InvalidState("mixture needs one weight per state")
  }
  let shape = states[0].shape
  let mut total = 0.0
  let mut correction = 0.0
  for i, state in states {
    if state.shape != shape {
      raise @error.RegisterMismatch
    }
    validate_norm(state)
    let weight = weights[i]
    if weight.is_nan() || weight.is_inf() || weight < 0.0 {
      raise @error.InvalidState(
        "mixture weights must be finite and nonnegative",
      )
    }
    let term = weight - correction
    let next = total + term
    correction = next - total - term
    total = next
  }
  if total.is_nan() || total.is_inf() || (total - 1.0).abs() > 1.0e-10 {
    raise @error.InvalidState("mixture weights must sum to one")
  }
  let matrix = empty_density(shape)
  for i, state in states {
    matrix.add_pure(state, weights[i] / total)
  }
  matrix.complete_hermitian()
  matrix
}

///|
/// Only the upper triangular part (including the diagonal) is computed.
/// The lower triangular part is reconstructed by `complete_hermitian`.
fn DensityMatrix::add_pure(
  self : DensityMatrix,
  state : StateVector,
  weight : Double,
) -> Unit {
  let size = self.size()
  for row in 0..<size {
    for column in row..<size {
      let index = row * size + column
      self.re[index] += weight *
        (state.re[row] * state.re[column] + state.im[row] * state.im[column])
      self.im[index] += weight *
        (state.im[row] * state.re[column] - state.re[row] * state.im[column])
    }
  }
}

///|
/// Complete the lower triangular part of the density matrix.
fn DensityMatrix::complete_hermitian(self : DensityMatrix) -> Unit {
  let size = self.size()
  for row in 0..<size {
    for column in (row + 1)..<size {
      self.re[column * size + row] = self.re[row * size + column]
      self.im[column * size + row] = -self.im[row * size + column]
    }
  }
}

///|
pub fn DensityMatrix::dim(self : DensityMatrix) -> Array[UInt32] {
  self.shape.to_array()
}

///|
pub fn DensityMatrix::size(self : DensityMatrix) -> Int32 {
  self.shape.size()
}

///|
pub fn DensityMatrix::entry(
  self : DensityMatrix,
  row : Int32,
  column : Int32,
) -> @maths.Complex raise @error.QError {
  let size = self.size()
  if row < 0 || row >= size {
    raise @error.InvalidBasis(row)
  }
  if column < 0 || column >= size {
    raise @error.InvalidBasis(column)
  }
  let index = row * size + column
  @maths.Complex::new(self.re[index], self.im[index])
}

///|
/// Copy all entries in row-major order.
pub fn DensityMatrix::entries(self : DensityMatrix) -> Array[@maths.Complex] {
  Array::makei(self.re.length(), i => {
    @maths.Complex::new(self.re[i], self.im[i])
  })
}

///|
/// Read computational-basis probabilities from the diagonal, clipping negative roundoff.
pub fn DensityMatrix::probabilities(self : DensityMatrix) -> Array[Double] {
  let size = self.size()
  Array::makei(size, i => Double::max(self.re[i * size + i], 0.0))
}

///|
/// Return the trace of the density matrix:
pub fn DensityMatrix::trace(self : DensityMatrix) -> Double {
  let size = self.size()
  let mut sum = 0.0
  let mut correction = 0.0
  for i in 0..<size {
    let term = self.re[i * size + i] - correction
    let next = sum + term
    correction = next - sum - term
    sum = next
  }
  sum
}

///|
/// Return the purity of the quantum state.
pub fn DensityMatrix::purity(self : DensityMatrix) -> Double {
  let mut sum = 0.0
  let mut correction = 0.0
  for i in 0..<self.re.length() {
    let term = self.re[i] * self.re[i] + self.im[i] * self.im[i] - correction
    let next = sum + term
    correction = next - sum - term
    sum = next
  }
  sum
}
