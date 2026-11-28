///|
/// A quantum state represented by a complex density matrix.
/// For a Bell pair, the wire dimensions are [2, 2]. The basis order is 00, 01, 10, 11.
///
/// $$
/// |\psi\rangle=\frac{|00\rangle+|11\rangle}{\sqrt{2}},\qquad \rho=|\psi\rangle\langle\psi|=\frac12 \begin{bmatrix}1 & 0 & 0 & 1 \\ 0 & 0 & 0 & 0 \\ 0 & 0 & 0 & 0 \\ 1 & 0 & 0 & 1\end{bmatrix}.
/// $$
///
/// The real and imaginary arrays store entries in row-major order. The imaginary
/// entries are all zero in this example. For a matrix of dimension d, the flat index is
///
/// $$
/// \mathrm{offset}(r,c)=r d+c.
/// $$
struct DensityMatrix {
  shape : @internal.Shape
  re : Array[Double]
  im : Array[Double]
}

///|
/// Check representable dimensions and entry count before allocating a matrix.
fn density_size(shape : @internal.Shape) -> Int32 raise StateError {
  let mut size = 1
  for i in 0..<shape.length() {
    let dimension = shape[i]
    if dimension == 0U {
      raise InvalidDimension(dimension)
    }
    if dimension > (2147483647 / size).reinterpret_as_uint() {
      raise SizeLimit(2147483647)
    }
    size *= dimension.reinterpret_as_int()
  }
  if size > 2147483647 / size {
    raise SizeLimit(2147483647)
  }
  size
}

///|
fn empty_density(shape : @internal.Shape) -> DensityMatrix raise StateError {
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
) -> DensityMatrix raise StateError {
  DensityMatrix::basis(dimensions, 0)
}

///|
pub fn DensityMatrix::basis(
  dimensions : Array[UInt32],
  index : Int32,
) -> DensityMatrix raise StateError {
  let shape = @internal.Shape::new(dimensions)
  let size = density_size(shape)
  if index < 0 || index >= size {
    raise InvalidBasis(index)
  }
  let matrix = empty_density(shape)
  matrix.re[index * size + index] = 1.0
  matrix
}

///|
/// Construct a density matrix from a normalized pure state.
///
/// $$
/// \rho=|\psi\rangle\langle\psi|.
/// $$
pub fn DensityMatrix::from_state(
  state : StateVector,
) -> DensityMatrix raise StateError {
  validate_norm(state)
  let matrix = empty_density(state.shape)
  matrix.add_pure(state, 1.0)
  matrix.complete_hermitian()
  matrix
}

///|
/// Mix pure states with finite, nonnegative weights that sum to one.
/// All states must have the same ordered wire dimensions. Inputs are copied.
///
/// $$
/// \rho=\sum_i p_i|\psi_i\rangle\langle\psi_i|.
/// $$
pub fn DensityMatrix::from_mixture(
  states : Array[StateVector],
  weights : Array[Double],
) -> DensityMatrix raise StateError {
  if states.is_empty() || states.length() != weights.length() {
    raise InvalidState("mixture needs one weight per state")
  }
  let shape = states[0].shape
  let mut total = 0.0
  let mut correction = 0.0
  for i, state in states {
    if state.shape != shape {
      raise RegisterMismatch
    }
    validate_norm(state)
    let weight = weights[i]
    if weight.is_nan() || weight.is_inf() || weight < 0.0 {
      raise InvalidState("mixture weights must be finite and nonnegative")
    }
    let term = weight - correction
    let next = total + term
    correction = next - total - term
    total = next
  }
  if total.is_nan() || total.is_inf() || (total - 1.0).abs() > 1.0e-10 {
    raise InvalidState("mixture weights must sum to one")
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
) -> @maths.Complex raise StateError {
  let size = self.size()
  if row < 0 || row >= size {
    raise InvalidBasis(row)
  }
  if column < 0 || column >= size {
    raise InvalidBasis(column)
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
pub fn DensityMatrix::marginal_probabilities(
  self : DensityMatrix,
  targets : Array[Int32],
) -> Array[Double] raise ShapeError {
  let size = self.size()
  let probabilities = Array::make(self.shape.selected_size(targets), 0.0)
  let corrections = Array::make(probabilities.length(), 0.0)
  let strides = self.shape.strides()
  for basis in 0..<size {
    let mut index = 0
    for wire in targets {
      let dimension = self.shape[wire].reinterpret_as_int()
      index = index * dimension + basis / strides[wire] % dimension
    }

    let term = self.re[basis * size + basis] - corrections[index]
    let next = probabilities[index] + term
    corrections[index] = next - probabilities[index] - term
    probabilities[index] = next
  }
  for i in 0..<probabilities.length() {
    probabilities[i] = Double::max(probabilities[i], 0.0)
  }
  probabilities
}

///|
/// Return the trace of the density matrix.
///
/// $$
/// \operatorname{Tr}(\rho)=\sum_i\rho_{ii}.
/// $$
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
///
/// $$
/// \operatorname{Tr}(\rho^2)=\sum_{i,j}|\rho_{ij}|^2.
/// $$
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

///|
pub fn DensityMatrix::copy(self : DensityMatrix) -> DensityMatrix {
  { shape: self.shape, re: self.re.copy(), im: self.im.copy(), }
}
