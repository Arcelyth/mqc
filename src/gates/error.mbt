///|
#derive(Debug)
pub(all) suberror GateError {
  /// A rotation angle must be finite.
  InvalidAngle(String)
}

///|
pub extend GateError with Debug::{to_repr}
