///|
/// Errors from selecting wires in a shape.
#derive(Debug)
pub(all) suberror ShapeError {
  InvalidBasis(Int32)
  DuplicateQid(Int32)
}

///|
pub extend ShapeError with Debug::{to_repr}
