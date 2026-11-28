///|
#derive(Debug)
pub(all) suberror NoiseError {
  /// A noise channel has invalid input.
  InvalidChannel(String)
  /// A noise model received the wrong number of targets.
  TargetCount(Int32, Int32)
}

///|
pub extend NoiseError with Debug::{to_repr}
