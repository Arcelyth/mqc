///|
pub fn[Q : @circuit.Qid] i(
  target : Q,
) -> @circuit.Operation[Q] raise @circuit.CircuitError {
  @circuit.Operation::new(@gates.i(), [target])
}

///|
pub fn[Q : @circuit.Qid] x(
  target : Q,
) -> @circuit.Operation[Q] raise @circuit.CircuitError {
  @circuit.Operation::new(@gates.x(), [target])
}

///|
pub fn[Q : @circuit.Qid] y(
  target : Q,
) -> @circuit.Operation[Q] raise @circuit.CircuitError {
  @circuit.Operation::new(@gates.y(), [target])
}

///|
pub fn[Q : @circuit.Qid] z(
  target : Q,
) -> @circuit.Operation[Q] raise @circuit.CircuitError {
  @circuit.Operation::new(@gates.z(), [target])
}

///|
pub fn[Q : @circuit.Qid] h(
  target : Q,
) -> @circuit.Operation[Q] raise @circuit.CircuitError {
  @circuit.Operation::new(@gates.h(), [target])
}

///|
pub fn[Q : @circuit.Qid] s(
  target : Q,
) -> @circuit.Operation[Q] raise @circuit.CircuitError {
  @circuit.Operation::new(@gates.s(), [target])
}

///|
pub fn[Q : @circuit.Qid] t(
  target : Q,
) -> @circuit.Operation[Q] raise @circuit.CircuitError {
  @circuit.Operation::new(@gates.t(), [target])
}

///|
pub fn[Q : @circuit.Qid] rx(
  angle : Double,
  target : Q,
) -> @circuit.Operation[Q] raise {
  @circuit.Operation::new(@gates.rx(angle), [target])
}

///|
pub fn[Q : @circuit.Qid] ry(
  angle : Double,
  target : Q,
) -> @circuit.Operation[Q] raise {
  @circuit.Operation::new(@gates.ry(angle), [target])
}

///|
pub fn[Q : @circuit.Qid] rz(
  angle : Double,
  target : Q,
) -> @circuit.Operation[Q] raise {
  @circuit.Operation::new(@gates.rz(angle), [target])
}

///|
pub fn[Q : @circuit.Qid] phase(
  angle : Double,
  target : Q,
) -> @circuit.Operation[Q] raise {
  @circuit.Operation::new(@gates.phase(angle), [target])
}

///|
#alias(cx)
pub fn[Q : @circuit.Qid] cnot(
  control : Q,
  target : Q,
) -> @circuit.Operation[Q] raise @circuit.CircuitError {
  @circuit.Operation::new(@gates.cnot(), [control, target])
}

///|
pub fn[Q : @circuit.Qid] cy(
  control : Q,
  target : Q,
) -> @circuit.Operation[Q] raise @circuit.CircuitError {
  @circuit.Operation::new(@gates.cy(), [control, target])
}

///|
pub fn[Q : @circuit.Qid] cz(
  first : Q,
  second : Q,
) -> @circuit.Operation[Q] raise @circuit.CircuitError {
  @circuit.Operation::new(@gates.cz(), [first, second])
}

///|
pub fn[Q : @circuit.Qid] swap(
  first : Q,
  second : Q,
) -> @circuit.Operation[Q] raise @circuit.CircuitError {
  @circuit.Operation::new(@gates.swap(), [first, second])
}

///|
pub fn[Q : @circuit.Qid] measure(
  targets : Array[Q],
  key~ : String = "m",
) -> @circuit.Operation[Q] raise @circuit.CircuitError {
  @circuit.measure(targets, key~)
}

///|
/// Reset the target qubit or qudit to its ground state.
/// The wire can be used again by later operations in the same circuit.
pub fn[Q : @circuit.Qid] reset(
  target : Q,
) -> @circuit.Operation[Q] raise @circuit.CircuitError {
  @circuit.Operation::new(@circuit.Channel::reset(target.dim()), [target])
}
