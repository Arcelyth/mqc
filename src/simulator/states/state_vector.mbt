///|
/// A quantum state represented by a complex state vector.
///
/// For example, a two-qubit state |ψ> = (|00> + |11>) / √2:
///
///   shape = [2, 2]
///   re    = [1/√2, 0, 0, 1/√2]
///   im    = [0,    0, 0, 0]
///
/// The entries are stored in basis-state order:
///   |00>, |01>, |10>, |11>.
pub struct StateVector {
  /// Ordered wire dimensions.
  shape : @internal.Shape
  /// Real components of the state amplitudes.
  re : Array[Double]
  /// Imaginary components of the state amplitudes.
  im : Array[Double]
}

///|
pub fn StateVector::zero(dimensions : Array[UInt32]) -> StateVector {
  let shape = @internal.Shape::new(dimensions)
  let size = shape.size()
  let re = Array::make(size, 0.0)
  // Amplitude of |0> |00> ... is 1.
  re[0] = 1.0
  { shape, re, im: Array::make(size, 0.0), }
}

///|
pub fn StateVector::basis(
  dimensions : Array[UInt32],
  index : Int32,
) -> StateVector raise @error.QError {
  let shape = @internal.Shape::new(dimensions)
  let size = shape.size()
  if index < 0 || index >= size {
    raise @error.QError::InvalidBasis(index)
  }
  let re = Array::make(size, 0.0)
  re[index] = 1.0
  { shape, re, im: Array::make(size, 0.0), }
}

///|
/// Accept only a finite, normalized state. Input amplitudes are copied.
/// Require exactly one amplitude per basis state and a finite tolerance in
/// (0, 1e-6]. 
pub fn StateVector::from_amplitudes(
  dimensions : Array[UInt32],
  amplitudes : Array[@maths.Complex],
  tolerance~ : Double = 1.0e-10,
) -> StateVector raise @error.QError {
  let shape = @internal.Shape::new(dimensions)
  let size = shape.size()
  if amplitudes.length() != size ||
    tolerance.is_nan() ||
    tolerance.is_inf() ||
    tolerance <= 0.0 ||
    tolerance > 1.0e-6 {
    raise @error.QError::InvalidState("invalid amplitude count or tolerance")
  }
  let mut norm = 0.0
  let mut correction = 0.0
  for amp in amplitudes {
    if !amp.is_finite() {
      raise @error.QError::InvalidState("amplitudes must be finite")
    }
    let term = amp.norm_squared() - correction
    let next = norm + term
    correction = next - norm - term
    norm = next
  }
  if norm.is_nan() || norm.is_inf() || (norm - 1.0).abs() > tolerance {
    raise @error.QError::InvalidState("amplitudes must have unit norm")
  }
  let scale = 1.0 / norm.sqrt()
  {
    shape,
    re: amplitudes.map(fn(a) { a.re * scale }),
    im: amplitudes.map(fn(a) { a.im * scale }),
  }
}

///|
pub fn StateVector::dim(self : StateVector) -> Array[UInt32] {
  self.shape.to_array()
}

///|
/// Return the product of the wire dimensions, the number of basis states.
pub fn StateVector::size(self : StateVector) -> Int32 {
  self.re.length()
}

///|
/// Read one complex amplitude by basis index.
pub fn StateVector::amplitude(
  self : StateVector,
  index : Int32,
) -> @maths.Complex raise @error.QError {
  if index < 0 || index >= self.re.length() {
    raise @error.QError::InvalidBasis(index)
  }
  { re: self.re[index], im: self.im[index], }
}

///|
/// Copy all amplitudes into a new array in mixed-radix basis order.
pub fn StateVector::amplitudes(self : StateVector) -> Array[@maths.Complex] {
  Array::makei(self.re.length(), fn(i) { { re: self.re[i], im: self.im[i], } })
}

///|
/// Return squared amplitude magnitudes in basis order.
pub fn StateVector::probabilities(self : StateVector) -> Array[Double] {
  Array::makei(self.re.length(), fn(i) {
    self.re[i] * self.re[i] + self.im[i] * self.im[i]
  })
}

///|
/// Sum squared amplitude magnitudes with compensated accumulation.
pub fn StateVector::norm_squared(self : StateVector) -> Double {
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
/// Sum conjugate(self.amplitude(i)) * other.amplitude(i) over basis indices.
pub fn StateVector::inner_product(
  self : StateVector,
  other : StateVector,
) -> @maths.Complex raise @error.QError {
  if self.shape != other.shape {
    raise @error.QError::RegisterMismatch
  }
  let mut re = 0.0
  let mut im = 0.0
  for i in 0..<self.re.length() {
    re += self.re[i] * other.re[i] + self.im[i] * other.im[i]
    im += self.re[i] * other.im[i] - self.im[i] * other.re[i]
  }
  { re, im, }
}

///|
/// Calculate the marginal probability distribution of the selected wires.
///
/// For each possible measurement outcome of targets, sum the probabilities
/// of all basis states that produce that outcome, ignoring the unselected wires.
pub fn StateVector::marginal_probabilities(
  self : StateVector,
  targets : Array[Int32],
) -> Array[Double] raise @error.QError {
  let size = self.shape.selected_size(targets)
  let prob = Array::make(size, 0.0)
  let corrections = Array::make(size, 0.0)
  let strides = self.shape.strides()
  for basis in 0..<self.re.length() {
    let mut index = 0
    for wire in targets {
      let dimension = self.shape[wire].reinterpret_as_int()
      index = index * dimension + basis / strides[wire] % dimension
    }
    let weight = self.re[basis] * self.re[basis] +
      self.im[basis] * self.im[basis]
    let term = weight - corrections[index]
    let next = prob[index] + term
    corrections[index] = next - prob[index] - term
    prob[index] = next
  }
  prob
}
