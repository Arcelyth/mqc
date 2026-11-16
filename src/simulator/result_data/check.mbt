///|
/// Reject unbound parameters and identify computational-basis measurements.
fn check_instruction(
  instruction : @circuit.Instruction,
) -> Bool raise @circuit.QuantumError {
  let effect = instruction.effect()
  if effect.parameters().length() != 0 {
    raise @circuit.InvalidState("unbound parameters are not supported")
  }
  effect.measurement_key() is Some(_)
}
