///|
#derive(Debug)
#alias(QuantumError)
pub(all) suberror QError {
  /// A wire dimension is below two. Carries that dimension.
  InvalidDimension(UInt32)
  /// A size budget is invalid or exceeded. Carries the reported limit.
  SizeLimit(Int32)
  /// Gate data or a gate capability violates its contract. Carries the reason.
  InvalidGate(String)
  /// Channel data violates its contract. Carries the reason.
  InvalidChannel(String)
  /// A logical ID repeats. Carries its position in the supplied array.
  DuplicateQid(Int32)
  /// Target count mismatch. Carries expected and actual wire counts.
  TargetCount(Int32, Int32)
  /// Wire shape mismatch. Carries target position, expected dimension, and actual
  /// dimension.
  DimensionMismatch(Int32, UInt32, UInt32)
  /// Ordered wire dimensions or required logical IDs differ.
  RegisterMismatch
  /// An index or basis digit is out of range. Carries the rejected value.
  InvalidBasis(Int32)
  /// State data or numerical output violates its contract. Carries the reason.
  InvalidState(String)
  /// A measurement condition is invalid or reads a key before it is measured.
  InvalidCondition(String)
  /// A while condition remained true after this many iterations.
  IterationLimit(Int32)
}

///|
pub extend QError with Debug::{to_repr}
