///|
/// Wrap a real gate coefficient as a complex number.
fn real(value : Double) -> @maths.Complex {
  @maths.Complex::real(value)
}

///|
/// Build a checked one-qubit gate from a fixed, known unitary table.
fn fixed(name : String, values : Array[@maths.Complex]) -> @circuit.Gate {
  try! @circuit.Gate::unitary(name, [2U], values)
}

///|
/// Identity matrix on one qubit. Basis order: [0, 1].
///
/// ```text
/// [ 1  0 ]
/// [ 0  1 ]
/// ```
pub fn i() -> @circuit.Gate {
  fixed("I", [real(1.0), real(0.0), real(0.0), real(1.0)])
}

///|
/// Pauli X matrix on one qubit. Basis order: [0, 1].
///
/// ```text
/// [ 0  1 ]
/// [ 1  0 ]
/// ```
pub fn x() -> @circuit.Gate {
  fixed("X", [real(0.0), real(1.0), real(1.0), real(0.0)])
}

///|
/// Pauli Y matrix on one qubit. Basis order: [0, 1].
///
/// ```text
/// [ 0  -i ]
/// [ i   0 ]
/// ```
pub fn y() -> @circuit.Gate {
  fixed("Y", [
    real(0.0),
    { re: 0.0, im: -1.0, },
    { re: 0.0, im: 1.0, },
    real(0.0),
  ])
}

///|
/// Pauli Z matrix on one qubit. Basis order: [0, 1].
///
/// ```text
/// [ 1   0 ]
/// [ 0  -1 ]
/// ```
pub fn z() -> @circuit.Gate {
  fixed("Z", [real(1.0), real(0.0), real(0.0), real(-1.0)])
}

///|
/// Hadamard matrix on one qubit. Basis order: [0, 1].
///
/// ```text
/// 1/sqrt(2) * [ 1   1 ]
///             [ 1  -1 ]
/// ```
pub fn h() -> @circuit.Gate {
  let s = 1.0 / 2.0.sqrt()
  fixed("H", [real(s), real(s), real(s), real(-s)])
}

///|
/// S matrix on one qubit. Basis order: [0, 1].
///
/// ```text
/// [ 1  0 ]
/// [ 0  i ]
/// ```
pub fn s() -> @circuit.Gate {
  fixed("S", [real(1.0), real(0.0), real(0.0), { re: 0.0, im: 1.0, }])
}

///|
/// T matrix on one qubit. Basis order: [0, 1].
///
/// ```text
/// [ 1,             0 ]
/// [ 0, (1+i)/sqrt(2) ]
/// ```
pub fn t() -> @circuit.Gate {
  fixed("T", [
    real(1.0),
    real(0.0),
    real(0.0),
    @maths.Complex::phase(@math.PI / 4.0),
  ])
}

///|
/// Require a finite rotation angle before computing gate coefficients.
fn check_angle(angle : Double) -> Unit raise @circuit.QuantumError {
  if angle.is_nan() || angle.is_inf() {
    raise @circuit.InvalidGate("angle must be finite")
  }
}

///|
/// X rotation matrix on one qubit. Basis order: [0, 1].
/// The angle is in radians and must be finite.
///
/// ```text
/// c = cos(angle/2), s = sin(angle/2)
///
/// [    c  -i*s ]
/// [ -i*s     c ]
/// ```
pub fn rx(angle : Double) -> @circuit.Gate raise @circuit.QuantumError {
  check_angle(angle)
  let c = real(@math.cos(angle / 2.0))
  let s : @maths.Complex = { re: 0.0, im: -@math.sin(angle / 2.0), }
  @circuit.Gate::unitary("Rx", [2U], [c, s, s, c])
}

///|
/// Y rotation matrix on one qubit. Basis order: [0, 1].
/// The angle is in radians and must be finite.
///
/// ```text
/// c = cos(angle/2), s = sin(angle/2)
///
/// [ c  -s ]
/// [ s   c ]
/// ```
pub fn ry(angle : Double) -> @circuit.Gate raise @circuit.QuantumError {
  check_angle(angle)
  let c = real(@math.cos(angle / 2.0))
  let s = real(@math.sin(angle / 2.0))
  @circuit.Gate::unitary("Ry", [2U], [c, -s, s, c])
}

///|
/// Z rotation matrix on one qubit. Basis order: [0, 1].
/// The angle is in radians and must be finite. Both diagonal phases are kept.
///
/// ```text
/// c = cos(angle/2), s = sin(angle/2)
///
/// [ c-i*s      0 ]
/// [     0  c+i*s ]
/// ```
pub fn rz(angle : Double) -> @circuit.Gate raise @circuit.QuantumError {
  check_angle(angle)
  @circuit.Gate::unitary("Rz", [2U], [
    @maths.Complex::phase(-angle / 2.0),
    real(0.0),
    real(0.0),
    @maths.Complex::phase(angle / 2.0),
  ])
}

///|
/// Phase matrix on one qubit. Basis order: [0, 1].
/// The angle is in radians and must be finite.
///
/// ```text
/// [ 1                         0 ]
/// [ 0  cos(angle)+i*sin(angle) ]
/// ```
///
/// The first diagonal entry is exactly one. This differs from rz by a global
/// phase, which affects the result when adding a control.
pub fn phase(angle : Double) -> @circuit.Gate raise @circuit.QuantumError {
  check_angle(angle)
  @circuit.Gate::unitary("Phase", [2U], [
    real(1.0),
    real(0.0),
    real(0.0),
    @maths.Complex::phase(angle),
  ])
}
