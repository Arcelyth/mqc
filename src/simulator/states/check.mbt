///|
/// Reject unbound parameters and identify computational-basis measurements.
fn check_instruction(
  instruction : @circuit.Instruction,
) -> String? raise @error.QError {
  let effect = instruction.effect()
  if effect.parameters().length() != 0 {
    raise @error.QError::InvalidState("unbound parameters are not supported")
  }
  effect.measurement_key()
}
