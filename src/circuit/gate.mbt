///|
/// An immutable unitary effect.
struct Gate {
  label : String
  shape : @internal.Shape
  /// Immutable numerical kernel, shared by derived values when possible.
  kernel_value : &UnitaryKernel
}

///|
/// Check shape, finite entries, and U†U before accepting a matrix.
/// Entries are in row order: row * dimension + column.
/// Tolerance must be finite and in (0, 1e-6]; it bounds absolute errors in
/// column inner products. Accepted entries are kept without normalization.
pub fn Gate::unitary(
  name : String,
  dimensions : Array[UInt32],
  matrix : Array[@maths.Complex],
  tolerance~ : Double = 1.0e-10,
) -> Gate raise QuantumError {
  if tolerance.is_nan() ||
    tolerance.is_inf() ||
    tolerance <= 0.0 ||
    tolerance > 1.0e-6 {
    raise InvalidGate("tolerance must be finite and in (0, 1e-6]")
  }
  let shape = @internal.Shape::new(dimensions)
  let size = shape.size()
  if matrix.length() != size * size {
    raise InvalidGate("matrix size does not match the shape")
  }
  for entry in matrix {
    if !entry.is_finite() {
      raise InvalidGate("matrix entries must be finite")
    }
  }
  for col in 0..<size {
    for other in col..<size {
      let mut re = 0.0
      let mut im = 0.0
      for row in 0..<size {
        let a = matrix[row * size + col]
        let b = matrix[row * size + other]
        re += a.re * b.re + a.im * b.im
        im += a.re * b.im - a.im * b.re
      }
      let expected = if col == other { 1.0 } else { 0.0 }
      if (re - expected).abs() > tolerance ||
        im.abs() > tolerance ||
        re.is_nan() ||
        re.is_inf() ||
        im.is_nan() ||
        im.is_inf() {
        raise InvalidGate("matrix is not unitary")
      }
    }
  }
  { label: name, shape, kernel_value: matrix_kernel(matrix.copy(), size), }
}

///|
/// Bind a custom unitary kernel to a shape.
pub fn Gate::from_kernel(
  name : String,
  dimensions : Array[UInt32],
  kernel : &UnitaryKernel,
) -> Gate raise QuantumError {
  let shape = @internal.Shape::new(dimensions)
  let size = shape.size()
  if kernel.size() != size {
    raise InvalidGate("kernel dimension or workspace is invalid")
  }
  { label: name, shape, kernel_value: kernel, }
}

///|
/// Constructs a monomial unitary gate from a column permutation and phase factors.
pub fn Gate::monomial(
  name : String,
  dimensions : Array[UInt32],
  columns : Array[Int32],
  phases : Array[@maths.Complex],
) -> Gate raise QuantumError {
  let shape = @internal.Shape::new(dimensions)
  let size = shape.size()
  if columns.length() != size || phases.length() != size {
    raise InvalidGate("permutation size does not match the shape")
  }
  let seen = Array::make(size, false)
  for row, col in columns {
    if col < 0 || col >= size || seen[col] {
      raise InvalidGate("columns must be a permutation")
    }
    seen[col] = true
    let phase = phases[row]
    if !phase.is_finite() || (phase.norm_squared() - 1.0).abs() > 1.0e-10 {
      raise InvalidGate("phases must have unit magnitude")
    }
  }
  {
    label: name,
    shape,
    kernel_value: MonomialKernel::{
      columns: columns.copy(),
      phases: phases.copy(),
    },
  }
}

///|
/// Create a diagonal unitary from one phase per basis state.
pub fn Gate::diagonal(
  name : String,
  dimensions : Array[UInt32],
  phases : Array[@maths.Complex],
) -> Gate raise QuantumError {
  let shape = @internal.Shape::new(dimensions)
  let size = shape.size()
  Gate::monomial(name, dimensions, Array::makei(size, fn(i) { i }), phases)
}

///|
pub fn Gate::name(self : Gate) -> String {
  self.label
}

///|
pub fn Gate::dim(self : Gate) -> Array[UInt32] {
  self.shape.to_array()
}

///|
pub fn Gate::arity(self : Gate) -> Int32 {
  self.shape.length()
}

///|
pub fn Gate::size(self : Gate) -> Int32 {
  self.shape.size()
}

///|
pub fn Gate::shape(self : Gate) -> @internal.Shape {
  self.shape
}

///|
/// Return the immutable unitary kernel for this gate.
pub fn Gate::kernel(self : Gate) -> &UnitaryKernel {
  self.kernel_value
}

///|
/// Return the inverse unitary using the kernel's adjoint.
pub fn Gate::adjoint(self : Gate) -> Gate {
  {
    label: self.label + "†",
    shape: self.shape,
    kernel_value: self.kernel_value.adjoint(),
  }
}

///|
pub impl Effect for Gate with fn name(self) -> String {
  self.label
}

///|
pub impl Effect for Gate with fn dim(self) -> Array[UInt32] {
  self.shape.to_array()
}

///|
pub impl Effect for Gate with fn try_unitary(self) -> Gate? {
  Some(self)
}

///|
pub impl Debug for Gate with fn to_repr(self) {
  Debug::to_repr((self.label, self.shape.to_array()))
}

///|
pub extend Gate with Effect::{
  measurement_key,
  try_unitary,
  try_channel,
  try_decompose,
  try_adjoint,
  parameters,
}

///|
pub extend Gate with Debug::{to_repr}
