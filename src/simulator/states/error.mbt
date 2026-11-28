///|
/// Errors from state preparation, validation, or evolution.
#derive(Debug)
pub(all) suberror StateError {
  InvalidDimension(UInt32)
  SizeLimit(Int32)
  InvalidBasis(Int32)
  TargetCount(Int32, Int32)
  DimensionMismatch(Int32, UInt32, UInt32)
  RegisterMismatch
  InvalidState(String)
  InvalidGate(String)
  InvalidCondition(String)
  IterationLimit(Int32)
}

///|
pub extend StateError with Debug::{to_repr}

///|
pub using @internal {type ShapeError}
