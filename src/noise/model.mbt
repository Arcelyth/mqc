///|
pub using @circuit {trait NoiseModel}

///|
/// Apply the same one-wire channel to each target after a gate.
/// The channel's wire dimension must match the target's dimension.
struct PerTargetNoise {
  channel : @circuit.Channel
}

///|
/// Build a per-target noise model from a channel acting on one wire.
pub fn PerTargetNoise::new(
  channel : @circuit.Channel,
) -> PerTargetNoise raise NoiseError {
  if channel.arity() != 1 {
    raise TargetCount(1, channel.arity())
  }
  { channel, }
}

///|
pub impl NoiseModel for PerTargetNoise with fn after_gate(self, _, targets) {
  targets.iter().map(target => (self.channel, [target])).collect()
}

///|
pub extend PerTargetNoise with NoiseModel::{after_gate}
