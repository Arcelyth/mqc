///|
/// Identifies a quantum object. Equal IDs must have the same, fixed dimension.
/// Dimensions must be at least two.
pub(open) trait Qid: Eq + Hash {
  fn dim(Self) -> UInt32
}

///|
/// Measurement results available to a condition during one shot. Digits are
/// returned in target order. 
/// Reading a key before its measurement raises `InvalidCondition`.
pub(open) trait MeasurementRecord {
  fn latest(Self, String) -> ArrayView[Int32] raise @error.QError
}

///|
pub(open) trait NoiseModel {
  /// Choose channels to insert after a gate. The targets are zero-based positions
  /// in the input circuit's qids(), including idle wires.
  fn after_gate(Self, Gate, ArrayView[Int32]) -> Array[(Channel, Array[Int32])] raise @error.QError
}
