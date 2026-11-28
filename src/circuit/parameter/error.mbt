///|
#derive(Debug)
pub(all) suberror ParameterError {
  InvalidParameter(String)
  NameConflict(String)
}

///|
pub extend ParameterError with Debug::{to_repr}
