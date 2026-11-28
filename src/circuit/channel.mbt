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
  representation : ChannelRepresentation
}

///|
priv enum ChannelRepresentation {
  Kraus(Array[DenseKernel])
  Mixture(Array[(Double, Gate)])
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
/// Invalid dimensions or matrices raise `CircuitError`.
pub fn Channel::kraus(
  name : String,
  dimensions : Array[UInt32],
  operators : Array[Array[@maths.Complex]],
) -> Channel raise CircuitError {
  guard operators.get(0) is Some(first) else {
    raise InvalidChannel("at least one Kraus matrix is required")
  }
  let entries = first.length()
  let size = kraus_size(dimensions, entries)
  for matrix in operators {
    if matrix.length() != entries {
      raise InvalidChannel("Kraus matrix size does not match the shape")
    }
    if !matrix.all(entry => entry.is_finite()) {
      raise InvalidChannel("Kraus matrix entries must be finite")
    }
  }
  check_trace_preserving(operators, size)
  {
    label: name,
    shape: @internal.Shape::new(dimensions),
    representation: Kraus(
      operators.map(matrix => DenseKernel::{ data: matrix.copy(), size, }),
    ),
  }
}

///|
/// Check the product against the supplied matrix length before multiplying.
fn kraus_size(
  dimensions : Array[UInt32],
  entries : Int32,
) -> Int32 raise CircuitError {
  let mut size = 1
  for dimension in dimensions {
    if dimension < 2U {
      raise InvalidDimension(dimension)
    }
    if dimension > (entries / size).reinterpret_as_uint() {
      raise InvalidChannel("Kraus matrix size does not match the shape")
    }
    size *= dimension.reinterpret_as_int()
  }
  if entries / size != size || entries % size != 0 {
    raise InvalidChannel("Kraus matrix size does not match the shape")
  }
  size
}

///|
fn check_trace_preserving(
  operators : Array[Array[@maths.Complex]],
  size : Int32,
  tolerance~ : Double = 1.0e-10,
) -> Unit raise CircuitError {
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
        raise InvalidChannel("Kraus matrices must preserve trace")
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
) -> Channel raise CircuitError {
  if !(probability >= 0.0 && probability <= 1.0) {
    raise InvalidChannel("damping probability must be in [0, 1]")
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
  match self.representation {
    Kraus(operators) => operators.iter().map(operator => operator.data[:])
    Mixture(_) => self.kernels().map(kernel => kernel_matrix(kernel)[:])
  }
}

///|
/// Return the number of rows in each Kraus matrix.
pub fn Channel::size(self : Channel) -> Int32 {
  self.shape.size()
}

///|
/// Iterate over the linear kernels for the Kraus operators.
pub fn Channel::kernels(self : Channel) -> Iter[&LinearKernel] {
  match self.representation {
    Kraus(operators) => operators.iter().map(operator => operator)
    Mixture(terms) =>
      terms
      .iter()
      .map(term => {
        let (probability, gate) = term
        ScaledKernel::{ scale: probability.sqrt(), inner: gate.kernel(), }
      })
  }
}

///|
/// Choose one of the supplied gates with its stated probability. All gates
/// must act on the same ordered wire dimensions. Probabilities must be
/// finite, nonnegative, and sum to one within 1e-10.
///
/// $$
/// \mathcal{E}(\rho) = \sum_i p_i U_i \rho U_i^\dagger,
/// \qquad K_i = \sqrt{p_i}\,U_i.
/// $$
pub fn Channel::mixture(
  terms : Array[(Double, Gate)],
  name~ : String = "Mixture",
  tolerance~ : Double = 1.0e-10,
) -> Channel raise CircuitError {
  guard terms.get(0) is Some((_, first)) else {
    raise InvalidChannel("a unitary mixture needs at least one gate")
  }
  let shape = first.shape()
  // Each Kraus matrix must fit in one row-major array when requested.
  let mut size = 1
  for dimension in first.dim() {
    if dimension < 2U {
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
  let mut total = 0.0
  let mut correction = 0.0
  for (probability, gate) in terms {
    if !(probability >= 0.0 && probability <= 1.0) {
      raise InvalidChannel("mixture probabilities must be in [0, 1]")
    }
    if gate.shape() != shape {
      raise InvalidChannel(
        "mixture gates must have the same ordered wire dimensions",
      )
    }
    let term = probability - correction
    let next = total + term
    correction = next - total - term
    total = next
  }
  if (total - 1.0).abs() > tolerance {
    raise InvalidChannel("mixture probabilities must sum to one")
  }
  { label: name, shape, representation: Mixture(terms.copy()), }
}

///|
/// Read the fixed probabilities and gates of a mixed-unitary channel.
/// General Kraus channels have state-dependent outcome probabilities.
pub fn Channel::mixture_terms(self : Channel) -> ArrayView[(Double, Gate)]? {
  match self.representation {
    Mixture(terms) => Some(terms[:])
    Kraus(_) => None
  }
}

///|
/// Apply the kernel to each basis vector to get the matrix columns.
/// Only explicit matrix export needs this expansion.
fn kernel_matrix(kernel : &LinearKernel) -> Array[@maths.Complex] {
  let size = kernel.size()
  let matrix = Array::make(size * size, @maths.Complex::real(0.0))
  let basis = Array::make(size, 0.0)
  let zeros = Array::make(size, 0.0)
  let re = Array::make(size, 0.0)
  let im = Array::make(size, 0.0)
  for column in 0..<size {
    basis[column] = 1.0
    kernel.apply({
      input_re: basis[:],
      input_im: zeros[:],
      output_re: re.mut_view(),
      output_im: im.mut_view(),
    })
    for row in 0..<size {
      matrix[row * size + column] = @maths.Complex::new(re[row], im[row])
    }
    basis[column] = 0.0
  }
  matrix
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

///|
/// Prepare one wire of dimension `d` in the ground state. For each input
/// basis digit, one Kraus operator maps that digit to zero:
///
/// $$
/// K_j = |0\rangle\langle j|, \qquad j = 0,\ldots,d-1.
/// $$
///
/// Resetting one wire of an entangled state preserves the reduced state
/// of the other wires. The channel produces no measurement record.
pub fn Channel::reset(d : UInt32) -> Channel raise CircuitError {
  if d < 2U {
    raise InvalidDimension(d)
  }
  if d > 2147483647U / d {
    raise SizeLimit(2147483647)
  }
  let size = d.reinterpret_as_int()
  let zero = @maths.Complex::real(0.0)
  let one = @maths.Complex::real(1.0)
  let operators = Array::makei(size, digit => {
    let data = Array::make(size * size, zero)
    data[digit] = one
    DenseKernel::{ data, size, }
  })
  {
    label: "Reset",
    shape: @internal.Shape::new([d]),
    representation: Kraus(operators),
  }
}
