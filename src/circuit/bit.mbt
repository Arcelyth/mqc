///|
/// A logical qubit ID.
#alias(Qubit)
#derive(Eq, Hash, Compare, Debug)
pub(all) struct QubitId(UInt32)

///|
pub impl Qid for QubitId with fn name(_self) -> String {
  "Qubit"
}

///|
pub impl Qid for QubitId with fn id(self) -> UInt32 {
  self.0
}

///|
pub impl Qid for QubitId with fn dim(_self) -> UInt32 {
  2U
}

///|
pub impl Show for QubitId with fn output(self, logger) {
  logger.write_object(self.0)
}

///|
/// Identifies a qudit, a quantum system with a finite-dimensional
/// state space.
/// The `dim` field specifies the dimension of its local Hilbert space.
#alias(Qudit)
#derive(Eq, Hash, Debug)
struct QuditId {
  id : UInt32
  dim : UInt32
}

///|
pub fn QuditId::new(
  id : UInt32,
  dimension : UInt32,
) -> QuditId raise CircuitError {
  if dimension < 2U {
    raise InvalidDimension(dimension)
  }
  { id, dim: dimension, }
}

///|
pub impl Qid for QuditId with fn name(_self) -> String {
  "Qudit"
}

///|
pub impl Qid for QuditId with fn id(self) -> UInt32 {
  self.id
}

///|
pub impl Qid for QuditId with fn dim(self) -> UInt32 {
  self.dim
}

///|
pub impl Show for QuditId with fn output(self, logger) {
  logger.write_string("\{self.id}[\{self.dim}]")
}

///|
pub extend QubitId with Show::{output, to_string}

///|
pub extend QubitId with Eq::{equal, not_equal}

///|
pub extend QubitId with Hash::{hash, hash_combine}

///|
pub extend QubitId with Compare::{compare, op_lt, op_le, op_gt, op_ge}

///|
pub extend QubitId with Debug::{to_repr}

///|
pub extend QubitId with Qid::{name, id, dim}

///|
pub extend QuditId with Show::{output, to_string}

///|
pub extend QuditId with Eq::{equal, not_equal}

///|
pub extend QuditId with Hash::{hash, hash_combine}

///|
pub extend QuditId with Debug::{to_repr}

///|
pub extend QuditId with Qid::{name, id, dim}
