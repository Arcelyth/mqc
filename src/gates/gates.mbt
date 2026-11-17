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
/// Identity gate on one qubit.
///
///   I = [ 1  0 ]
///       [ 0  1 ]
pub fn i() -> @circuit.Gate {
  fixed("I", [real(1.0), real(0.0), real(0.0), real(1.0)])
}

///|
/// Pauli X gate on one qubit.
///
///   X = [ 0  1 ]
///       [ 1  0 ]
pub fn x() -> @circuit.Gate {
  fixed("X", [real(0.0), real(1.0), real(1.0), real(0.0)])
}

///|
/// Pauli Y gate on one qubit.
///
///   Y = [ 0  -i ]
///       [ i   0 ]
pub fn y() -> @circuit.Gate {
  fixed("Y", [
    real(0.0),
    { re: 0.0, im: -1.0, },
    { re: 0.0, im: 1.0, },
    real(0.0),
  ])
}

///|
/// Pauli Z gate on one qubit.
///
///   Z = [ 1   0 ]
///       [ 0  -1 ]
pub fn z() -> @circuit.Gate {
  fixed("Z", [real(1.0), real(0.0), real(0.0), real(-1.0)])
}

///|
/// Hadamard gate on one qubit.
///
///   H = (1 / sqrt(2)) * [ 1   1 ]
///                       [ 1  -1 ]
pub fn h() -> @circuit.Gate {
  let s = 1.0 / 2.0.sqrt()
  fixed("H", [real(s), real(s), real(s), real(-s)])
}

///|
/// Phase gate S on one qubit.
///
///   S = [ 1  0 ]
///       [ 0  i ]
pub fn s() -> @circuit.Gate {
  fixed("S", [real(1.0), real(0.0), real(0.0), { re: 0.0, im: 1.0, }])
}

///|
/// Phase gate T on one qubit.
///
///   T = [ 1                0 ]
///       [ 0  exp(i * pi / 4) ]
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
fn check_angle(angle : Double) -> Unit raise @error.QError {
  if angle.is_nan() || angle.is_inf() {
    raise @error.QError::InvalidGate("angle must be finite")
  }
}

///|
/// Rotation about X on one qubit.
/// The angle is in radians and must be finite.
///
///   c = cos(angle / 2), s = sin(angle / 2)
///   Rx(angle) = exp(-i * angle * X / 2)
///
///   Rx(angle) = [    c  -i*s ]
///               [ -i*s     c ]
pub fn rx(angle : Double) -> @circuit.Gate raise @error.QError {
  check_angle(angle)
  let c = real(@math.cos(angle / 2.0))
  let s : @maths.Complex = { re: 0.0, im: -@math.sin(angle / 2.0), }
  @circuit.Gate::unitary("Rx", [2U], [c, s, s, c])
}

///|
/// Rotation about Y on one qubit.
/// The angle is in radians and must be finite.
///
///   c = cos(angle / 2), s = sin(angle / 2)
///   Ry(angle) = exp(-i * angle * Y / 2)
///
///   Ry(angle) = [ c  -s ]
///               [ s   c ]
pub fn ry(angle : Double) -> @circuit.Gate raise @error.QError {
  check_angle(angle)
  let c = real(@math.cos(angle / 2.0))
  let s = real(@math.sin(angle / 2.0))
  @circuit.Gate::unitary("Ry", [2U], [c, -s, s, c])
}

///|
/// Rotation about Z on one qubit.
/// The angle is in radians and must be finite. Both diagonal phases are kept.
///
///   Rz(angle) = exp(-i * angle * Z / 2)
///
///   Rz(angle) = [ exp(-i * angle / 2)                   0 ]
///               [                   0  exp(i * angle / 2) ]
pub fn rz(angle : Double) -> @circuit.Gate raise @error.QError {
  check_angle(angle)
  @circuit.Gate::unitary("Rz", [2U], [
    @maths.Complex::phase(-angle / 2.0),
    real(0.0),
    real(0.0),
    @maths.Complex::phase(angle / 2.0),
  ])
}

///|
/// Phase gate on one qubit.
/// The angle is in radians and must be finite.
///
///   P(angle) = [ 1               0 ]
///              [ 0  exp(i * angle) ]
///
///   P(angle) = exp(i * angle / 2) * Rz(angle)
///
/// The first diagonal entry is exactly one. The global phase relative to
/// Rz(angle) affects the result when adding a control.
pub fn phase(angle : Double) -> @circuit.Gate raise @error.QError {
  check_angle(angle)
  @circuit.Gate::unitary("Phase", [2U], [
    real(1.0),
    real(0.0),
    real(0.0),
    @maths.Complex::phase(angle),
  ])
}

///|
/// Controlled X, with the control wire first.
///
///   CNOT = [ 1  0  0  0 ]
///          [ 0  1  0  0 ]
///          [ 0  0  0  1 ]
///          [ 0  0  1  0 ]
#alias(cx)
pub fn cnot() -> @circuit.Gate {
  try! @circuit.Gate::monomial(
    "CNOT",
    [2U, 2U],
    [0, 1, 3, 2],
    Array::make(4, real(1.0)),
  )
}

///|
/// Controlled Y, with the control wire first.
///
///   CY = [ 1  0  0   0 ]
///        [ 0  1  0   0 ]
///        [ 0  0  0  -i ]
///        [ 0  0  i   0 ]
pub fn cy() -> @circuit.Gate {
  try! @circuit.Gate::monomial("CY", [2U, 2U], [0, 1, 3, 2], [
    real(1.0),
    real(1.0),
    @maths.Complex::new(0.0, -1.0),
    @maths.Complex::new(0.0, 1.0),
  ])
}

///|
/// Multiply |11> by -1 and leave the other basis states unchanged.
///
///   CZ = [ 1  0  0   0 ]
///        [ 0  1  0   0 ]
///        [ 0  0  1   0 ]
///        [ 0  0  0  -1 ]
pub fn cz() -> @circuit.Gate {
  try! @circuit.Gate::diagonal("CZ", [2U, 2U], [
    real(1.0),
    real(1.0),
    real(1.0),
    real(-1.0),
  ])
}

///|
/// Exchange two qubits.
///
///   SWAP = [ 1  0  0  0 ]
///          [ 0  0  1  0 ]
///          [ 0  1  0  0 ]
///          [ 0  0  0  1 ]
pub fn swap() -> @circuit.Gate {
  try! @circuit.Gate::monomial(
    "SWAP",
    [2U, 2U],
    [0, 2, 1, 3],
    Array::make(4, real(1.0)),
  )
}
