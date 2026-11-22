///|
/// Reject unresolved parameters before executing an instruction.
fn check_instruction(
  instruction : @circuit.Instruction[Int32],
) -> Unit raise @error.QError {
  if instruction.parameters().length() != 0 {
    raise @error.QError::InvalidState("unbound parameters are not supported")
  }
}
