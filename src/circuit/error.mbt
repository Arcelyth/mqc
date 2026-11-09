///|
#derive(Debug)
pub(all) suberror QuantumError {
  /// A wire dimension is below two; carries that dimension.
  InvalidDimension(UInt32)
  /// A size budget is invalid or exceeded; carries the reported limit.
  SizeLimit(Int32)
  /// Gate data or a gate capability violates its contract; carries the reason.
  InvalidGate(String)
  /// A logical ID repeats; carries its position in the supplied array.
  DuplicateQid(Int32)
  /// Target count mismatch; carries expected and actual wire counts.
  TargetCount(Int32, Int32)
  /// Wire shape mismatch; carries target position, expected dimension, and actual
  /// dimension.
  DimensionMismatch(Int32, UInt32, UInt32)
  /// Ordered wire dimensions or required logical IDs differ.
  RegisterMismatch
  /// An index or basis digit is out of range; carries the rejected value.
  InvalidBasis(Int32)
  /// State data or numerical output violates its contract; carries the reason.
  InvalidState(String)
  /// A save instruction has an invalid label, wire binding, or representation.
}

///|
pub extend QuantumError with Debug::{to_repr}
