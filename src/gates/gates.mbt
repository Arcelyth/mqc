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
/// $$
/// I = \begin{bmatrix}
/// 1 & 0 \\
/// 0 & 1
/// \end{bmatrix}.
/// $$
pub fn i() -> @circuit.Gate {
  fixed("I", [real(1.0), real(0.0), real(0.0), real(1.0)])
}

///|
/// Pauli $X$ gate on one qubit.
///
/// $$
/// X = \begin{bmatrix}
/// 0 & 1 \\
/// 1 & 0
/// \end{bmatrix}.
/// $$
pub fn x() -> @circuit.Gate {
  fixed("X", [real(0.0), real(1.0), real(1.0), real(0.0)])
}

///|
/// Pauli $Y$ gate on one qubit.
///
/// $$
/// Y = \begin{bmatrix}
/// 0 & -i \\
/// i & 0
/// \end{bmatrix}.
/// $$
pub fn y() -> @circuit.Gate {
  fixed("Y", [
    real(0.0),
    { re: 0.0, im: -1.0, },
    { re: 0.0, im: 1.0, },
    real(0.0),
  ])
}

///|
/// Pauli $Z$ gate on one qubit.
///
/// $$
/// Z = \begin{bmatrix}
/// 1 & 0 \\
/// 0 & -1
/// \end{bmatrix}.
/// $$
pub fn z() -> @circuit.Gate {
  fixed("Z", [real(1.0), real(0.0), real(0.0), real(-1.0)])
}

///|
/// Hadamard gate on one qubit.
///
/// $$
/// H = \frac{1}{\sqrt{2}}\begin{bmatrix}
/// 1 & 1 \\
/// 1 & -1
/// \end{bmatrix}.
/// $$
pub fn h() -> @circuit.Gate {
  let s = 1.0 / 2.0.sqrt()
  fixed("H", [real(s), real(s), real(s), real(-s)])
}

///|
/// Phase gate $S$ on one qubit.
///
/// $$
/// S = \begin{bmatrix}
/// 1 & 0 \\
/// 0 & i
/// \end{bmatrix}.
/// $$
pub fn s() -> @circuit.Gate {
  fixed("S", [real(1.0), real(0.0), real(0.0), { re: 0.0, im: 1.0, }])
}

///|
/// Phase gate $T$ on one qubit.
///
/// $$
/// T = \begin{bmatrix}
/// 1 & 0 \\
/// 0 & e^{i\pi/4}
/// \end{bmatrix}.
/// $$
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
/// Rotation about $X$ on one qubit.
/// The angle $\theta$ is in radians and must be finite.
///
/// $$
/// R_x(\theta) = e^{-i\theta X/2} = \begin{bmatrix}
/// \cos(\theta/2) & -i\sin(\theta/2) \\
/// -i\sin(\theta/2) & \cos(\theta/2)
/// \end{bmatrix}.
/// $$
pub fn rx(angle : Double) -> @circuit.Gate raise @circuit.QuantumError {
  check_angle(angle)
  let c = real(@math.cos(angle / 2.0))
  let s : @maths.Complex = { re: 0.0, im: -@math.sin(angle / 2.0), }
  @circuit.Gate::unitary("Rx", [2U], [c, s, s, c])
}

///|
/// Rotation about $Y$ on one qubit.
/// The angle $\theta$ is in radians and must be finite.
///
/// $$
/// R_y(\theta) = e^{-i\theta Y/2} = \begin{bmatrix}
/// \cos(\theta/2) & -\sin(\theta/2) \\
/// \sin(\theta/2) & \cos(\theta/2)
/// \end{bmatrix}.
/// $$
pub fn ry(angle : Double) -> @circuit.Gate raise @circuit.QuantumError {
  check_angle(angle)
  let c = real(@math.cos(angle / 2.0))
  let s = real(@math.sin(angle / 2.0))
  @circuit.Gate::unitary("Ry", [2U], [c, -s, s, c])
}

///|
/// Rotation about $Z$ on one qubit.
/// The angle $\theta$ is in radians and must be finite. Both diagonal phases are kept.
///
/// $$
/// R_z(\theta) = e^{-i\theta Z/2} = \begin{bmatrix}
/// e^{-i\theta/2} & 0 \\
/// 0 & e^{i\theta/2}
/// \end{bmatrix}.
/// $$
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
/// Phase gate on one qubit.
/// The angle $\theta$ is in radians and must be finite.
///
/// $$
/// P(\theta) = \begin{bmatrix}
/// 1 & 0 \\
/// 0 & e^{i\theta}
/// \end{bmatrix}
/// = e^{i\theta/2}R_z(\theta).
/// $$
///
/// The first diagonal entry is exactly one. The global phase relative to
/// $R_z(\theta)$ affects the result when adding a control.
pub fn phase(angle : Double) -> @circuit.Gate raise @circuit.QuantumError {
  check_angle(angle)
  @circuit.Gate::unitary("Phase", [2U], [
    real(1.0),
    real(0.0),
    real(0.0),
    @maths.Complex::phase(angle),
  ])
}

///|
/// Controlled $X$, with the control wire first.
///
/// $$
/// \operatorname{CNOT} = \begin{bmatrix}
/// 1 & 0 & 0 & 0 \\
/// 0 & 1 & 0 & 0 \\
/// 0 & 0 & 0 & 1 \\
/// 0 & 0 & 1 & 0
/// \end{bmatrix}.
/// $$
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
/// Controlled $Y$, with the control wire first.
///
/// $$
/// \operatorname{CY} = \begin{bmatrix}
/// 1 & 0 & 0 & 0 \\
/// 0 & 1 & 0 & 0 \\
/// 0 & 0 & 0 & -i \\
/// 0 & 0 & i & 0
/// \end{bmatrix}.
/// $$
pub fn cy() -> @circuit.Gate {
  try! @circuit.Gate::monomial("CY", [2U, 2U], [0, 1, 3, 2], [
    real(1.0),
    real(1.0),
    @maths.Complex::new(0.0, -1.0),
    @maths.Complex::new(0.0, 1.0),
  ])
}

///|
/// Multiply $|11\rangle$ by $-1$ and leave the other basis states unchanged.
///
/// $$
/// \operatorname{CZ} = \begin{bmatrix}
/// 1 & 0 & 0 & 0 \\
/// 0 & 1 & 0 & 0 \\
/// 0 & 0 & 1 & 0 \\
/// 0 & 0 & 0 & -1
/// \end{bmatrix}.
/// $$
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
/// $$
/// \operatorname{SWAP} = \begin{bmatrix}
/// 1 & 0 & 0 & 0 \\
/// 0 & 0 & 1 & 0 \\
/// 0 & 1 & 0 & 0 \\
/// 0 & 0 & 0 & 1
/// \end{bmatrix}.
/// $$
pub fn swap() -> @circuit.Gate {
  try! @circuit.Gate::monomial(
    "SWAP",
    [2U, 2U],
    [0, 2, 1, 3],
    Array::make(4, real(1.0)),
  )
}
