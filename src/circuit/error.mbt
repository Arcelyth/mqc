///|
/// Errors from building circuits, operations, and effects.
#derive(Debug)
pub(all) suberror CircuitError {
  /// A wire dimension is below two.
  InvalidDimension(UInt32)
  /// A size budget is invalid or exceeded.
  SizeLimit(Int32)
  /// Gate data or an effect capability violates its contract.
  InvalidGate(String)
  /// Channel data violates its contract.
  InvalidChannel(String)
  /// A logical ID repeats at this position.
  DuplicateQid(Int32)
  /// The expected and actual target counts differ.
  TargetCount(Int32, Int32)
  /// A target's position, expected dimension, and actual dimension.
  DimensionMismatch(Int32, UInt32, UInt32)
  /// A wire index is out of range.
  InvalidBasis(Int32)
  /// The requested circuit action is invalid.
  InvalidState(String)
  /// A measurement condition is invalid or reads an unavailable result.
  InvalidCondition(String)
  /// A circuit's parameter expressions or indexes are invalid.
  Parameter(ParameterError)
}

///|
pub extend CircuitError with Debug::{to_repr}
