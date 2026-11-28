///|
/// Errors from setting up a simulation or sampling run.
#derive(Debug)
pub(all) suberror SimulatorError {
  /// The initial state's dimensions differ from the program's.
  RegisterMismatch
  /// The requested simulation or sampling run is invalid.
  InvalidState(String)
  /// The result would exceed the supported size.
  SizeLimit(Int32)
}

///|
pub extend SimulatorError with Debug::{to_repr}
