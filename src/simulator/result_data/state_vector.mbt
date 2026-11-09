///|
/// A quantum state represented by a complex state vector.
///
/// For example, a two-qubit state |ψ⟩ = (|00⟩ + |11⟩) / √2:
///
///   shape = [2, 2]
///   re    = [1/√2, 0, 0, 1/√2]
///   im    = [0,    0, 0, 0]
///
/// The entries are stored in basis-state order:
///   |00⟩, |01⟩, |10⟩, |11⟩.
pub struct StateVector {
  /// Ordered wire dimensions.
  shape : Array[UInt32]
  /// Real components of the state amplitudes.
  re : Array[Double]
  /// Imaginary components of the state amplitudes.
  im : Array[Double]
}

///|
pub fn StateVector::zero(
  dimensions : Array[UInt32],
) -> StateVector raise @circuit.QuantumError {
  let size = @circuit.space_size(dimensions)
  let re = Array::make(size, 0.0)
  // Amplitude of |0⟩, |00⟩, ... is 1.
  re[0] = 1.0
  { shape: dimensions.copy(), re, im: Array::make(size, 0.0), }
}

///|
pub fn StateVector::basis(
  dimensions : Array[UInt32],
  index : Int32,
) -> StateVector raise @circuit.QuantumError {
  let size = @circuit.space_size(dimensions)
  if index < 0 || index >= size {
    raise @circuit.InvalidBasis(index)
  }
  let re = Array::make(size, 0.0)
  re[index] = 1.0
  { shape: dimensions.copy(), re, im: Array::make(size, 0.0), }
}

///|
/// Accept only a finite, normalized state. Input amplitudes are copied.
/// Require exactly one amplitude per basis state and a finite tolerance in
/// (0, 1e-6]. 
pub fn StateVector::from_amplitudes(
  dimensions : Array[UInt32],
  amplitudes : Array[@maths.Complex],
  tolerance~ : Double = 1.0e-10,
) -> StateVector raise @circuit.QuantumError {
  let size = @circuit.space_size(dimensions)
  if amplitudes.length() != size ||
    tolerance.is_nan() ||
    tolerance.is_inf() ||
    tolerance <= 0.0 ||
    tolerance > 1.0e-6 {
    raise @circuit.InvalidState("invalid amplitude count or tolerance")
  }
  let mut norm = 0.0
  let mut correction = 0.0
  for amp in amplitudes {
    if !amp.is_finite() {
      raise @circuit.InvalidState("amplitudes must be finite")
    }
    let term = amp.norm_squared() - correction
    let next = norm + term
    correction = next - norm - term
    norm = next
  }
  if norm.is_nan() || norm.is_inf() || (norm - 1.0).abs() > tolerance {
    raise @circuit.InvalidState("amplitudes must have unit norm")
  }
  let scale = 1.0 / norm.sqrt()
  {
    shape: dimensions.copy(),
    re: amplitudes.map(fn(a) { a.re * scale }),
    im: amplitudes.map(fn(a) { a.im * scale }),
  }
}

///|
pub fn StateVector::dimensions(self : StateVector) -> Array[UInt32] {
  self.shape.copy()
}

///|
/// Return the product of the wire dimensions, the number of basis states.
pub fn StateVector::dimension(self : StateVector) -> Int32 {
  self.re.length()
}

///|
/// Read one complex amplitude by basis index.
pub fn StateVector::amplitude(
  self : StateVector,
  index : Int32,
) -> @maths.Complex raise @circuit.QuantumError {
  if index < 0 || index >= self.re.length() {
    raise @circuit.InvalidBasis(index)
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
) -> @maths.Complex raise @circuit.QuantumError {
  if self.shape != other.shape {
    raise @circuit.RegisterMismatch
  }
  let mut re = 0.0
  let mut im = 0.0
  for i in 0..<self.re.length() {
    re += self.re[i] * other.re[i] + self.im[i] * other.im[i]
    im += self.re[i] * other.im[i] - self.im[i] * other.re[i]
  }
  { re, im, }
}
