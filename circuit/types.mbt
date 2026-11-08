///|
/// Identifies a quantum object. Equal IDs must have the same, fixed dimension.
/// Dimensions must be at least two.
pub(open) trait Qid: Eq + Hash {
  fn dimension(Self) -> UInt32
}
