///|
/// A logical qubit ID with no device position.
#derive(Eq, Hash, Compare, Debug)
pub(all) struct QubitId(UInt64)

///|
pub impl Qid for QubitId with fn dimension(_self) -> UInt32 {
  2U
}

///|
/// Identifies a qudit, a quantum system with a finite-dimensional
/// state space.
/// The `levels` field specifies the dimension of its local Hilbert space.
#derive(Eq, Hash, Debug)
struct QuditId {
  id : UInt64
  levels : UInt32
}

///|
pub fn QuditId::new(
  id : UInt64,
  dimension : UInt32,
) -> QuditId raise QuantumError {
  if dimension < 2U {
    raise InvalidDimension(dimension)
  }
  { id, levels: dimension, }
}

///|
pub fn QuditId::value(self : QuditId) -> UInt64 {
  self.id
}

///|
pub impl Qid for QuditId with fn dimension(self) -> UInt32 {
  self.levels
}

///|
pub extend QubitId with Eq::{equal, not_equal}

///|
pub extend QubitId with Hash::{hash, hash_combine}

///|
pub extend QubitId with Compare::{compare, op_lt, op_le, op_gt, op_ge}

///|
pub extend QubitId with Debug::{to_repr}

///|
pub extend QubitId with Qid::{dimension}

///|
pub extend QuditId with Eq::{equal, not_equal}

///|
pub extend QuditId with Hash::{hash, hash_combine}

///|
pub extend QuditId with Debug::{to_repr}

///|
pub extend QuditId with Qid::{dimension}
