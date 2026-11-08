///|
#derive(Debug)
pub(all) suberror QuantumError {
  InvalidDimension(UInt32)
}

///|
pub extend QuantumError with Debug::{to_repr}
