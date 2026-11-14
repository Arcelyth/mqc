///|
/// A backend that samples a compiled program.
pub(open) trait Sampler {
  /// Omitted repetitions means one shot.
  fn run(Self, @circuit.Program, repetitions? : Int32) -> SamplerResult raise @circuit.QuantumError
}
