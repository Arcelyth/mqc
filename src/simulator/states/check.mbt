///|
/// Reject unresolved parameters before executing an instruction.
fn check_instruction(
  instruction : @circuit.Instruction[Int32],
) -> Unit raise StateError {
  if instruction.parameters().length() != 0 {
    raise InvalidState("unbound parameters are not supported")
  }
}
