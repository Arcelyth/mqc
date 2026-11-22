///|
/// A quantum channel defined by Kraus operators.
///
/// The channel transforms a density matrix as follows.
///
/// $$
/// \mathcal{E}(\rho) = \sum_k K_k \rho K_k^\dagger.
/// $$
struct Channel {
  label : String
  shape : @internal.Shape
  operators : Array[DenseKernel]
}

///|
/// Create a channel from a nonempty array of Kraus matrices.
///
/// Each wire dimension must be at least 2. The first wire varies slowest
/// in the basis. For example, `dimensions = [2U, 3U]` requires
/// 6-by-6 matrices. Pass each matrix as a flat array in row-major order.
///
/// Matrix entries must be finite. The Kraus matrices must satisfy
///
/// $$
/// \sum_k K_k^\dagger K_k = I.
/// $$
///
/// Invalid dimensions or matrices raise `QError`.
pub fn Channel::kraus(
  name : String,
  dimensions : Array[UInt32],
  operators : Array[Array[@maths.Complex]],
) -> Channel raise @error.QError {
  guard operators.get(0) is Some(first) else {
    raise @error.InvalidChannel("at least one Kraus matrix is required")
  }
  let entries = first.length()
  let size = kraus_size(dimensions, entries)
  for matrix in operators {
    if matrix.length() != entries {
      raise @error.InvalidChannel("Kraus matrix size does not match the shape")
    }
    if !matrix.all(entry => entry.is_finite()) {
      raise @error.InvalidChannel("Kraus matrix entries must be finite")
    }
  }
  check_trace_preserving(operators, size)
  {
    label: name,
    shape: @internal.Shape::new(dimensions),
    operators: operators.map(matrix => DenseKernel::{
      data: matrix.copy(),
      size,
    }),
  }
}

///|
/// Check the product against the supplied matrix length before multiplying.
fn kraus_size(
  dimensions : Array[UInt32],
  entries : Int32,
) -> Int32 raise @error.QError {
  let mut size = 1
  for dimension in dimensions {
    if dimension < 2U {
      raise @error.InvalidDimension(dimension)
    }
    if dimension > (entries / size).reinterpret_as_uint() {
      raise @error.InvalidChannel("Kraus matrix size does not match the shape")
    }
    size *= dimension.reinterpret_as_int()
  }
  if entries / size != size || entries % size != 0 {
    raise @error.InvalidChannel("Kraus matrix size does not match the shape")
  }
  size
}

///|
fn check_trace_preserving(
  operators : Array[Array[@maths.Complex]],
  size : Int32,
) -> Unit raise @error.QError {
  let tolerance = 1.0e-10
  for column in 0..<size {
    for other in column..<size {
      let mut re = 0.0
      let mut im = 0.0
      for matrix in operators {
        for row in 0..<size {
          let a = matrix[row * size + column]
          let b = matrix[row * size + other]
          re += a.re * b.re + a.im * b.im
          im += a.re * b.im - a.im * b.re
        }
      }
      let expected = if column == other { 1.0 } else { 0.0 }
      if !((re - expected).abs() <= tolerance && im.abs() <= tolerance) {
        raise @error.InvalidChannel("Kraus matrices must preserve trace")
      }
    }
  }
}

///|
/// Create a single-qubit amplitude damping channel.
///
/// `probability` is the chance that a qubit in the excited state decays to
/// the ground state. A qubit already in the ground state stays there.
/// The probability must be between 0 and 1, inclusive.
///
/// The Kraus matrices below use `p` for the decay probability.
///
/// $$
/// K_0 = \begin{bmatrix} 1 & 0 \\ 0 & \sqrt{1-p} \end{bmatrix},
/// \qquad
/// K_1 = \begin{bmatrix} 0 & \sqrt{p} \\ 0 & 0 \end{bmatrix}.
/// $$
pub fn Channel::amplitude_damp(
  probability : Double,
) -> Channel raise @error.QError {
  if !(probability >= 0.0 && probability <= 1.0) {
    raise @error.InvalidChannel("damping probability must be in [0, 1]")
  }
  let zero = @maths.Complex::real(0.0)
  Channel::kraus("AmplitudeDamping", [2U], [
    [
      @maths.Complex::real(1.0),
      zero,
      zero,
      @maths.Complex::real((1.0 - probability).sqrt()),
    ],
    [zero, @maths.Complex::real(probability.sqrt()), zero, zero],
  ])
}

///|
pub fn Channel::shape(self : Channel) -> @internal.Shape {
  self.shape
}

///|
/// Iterate over the Kraus matrices. Each view contains one matrix in row-major order.
pub fn Channel::kraus_operators(
  self : Channel,
) -> Iter[ArrayView[@maths.Complex]] {
  self.operators.iter().map(operator => operator.data[:])
}

///|
/// Return the number of rows in each Kraus matrix.
pub fn Channel::size(self : Channel) -> Int32 {
  self.shape.size()
}

///|
/// Iterate over the linear kernels for the Kraus operators.
pub fn Channel::kernels(self : Channel) -> Iter[&LinearKernel] {
  self.operators.iter().map(operator => operator)
}

///|
pub impl Effect for Channel with fn name(self) -> String {
  self.label
}

///|
pub impl Effect for Channel with fn dim(self) -> Array[UInt32] {
  self.shape.to_array()
}

///|
pub impl Effect for Channel with fn try_channel(self) -> Channel? {
  Some(self)
}

///|
pub extend Channel with Effect::{
  name,
  dim,
  arity,
  measurement_key,
  try_conditional,
  try_unitary,
  try_channel,
  try_decompose,
  try_adjoint,
  parameters,
}
