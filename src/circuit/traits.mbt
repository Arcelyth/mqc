///|
pub(open) trait Id: Eq + Hash {
  fn name(Self) -> String
  fn id(Self) -> UInt32
}

///|
/// Identifies a quantum object. Equal IDs must have the same, fixed dimension.
/// Dimensions must be at least two.
pub(open) trait Qid: Id {
  fn dim(Self) -> UInt32
  fn is_dim(Self, UInt32) -> Bool = _
}

///|
impl Qid with fn is_dim(self, dim : UInt32) -> Bool {
  self.dim() == dim
}

///|
/// Measurement results available to a condition during one shot. Digits are
/// returned in target order. 
/// Reading a key before its measurement raises `InvalidCondition`.
pub(open) trait MeasurementRecord {
  fn latest(Self, String) -> ArrayView[Int32] raise CircuitError
}

///|
pub(open) trait NoiseModel {
  /// Choose channels to insert after a gate. The targets are zero-based positions
  /// in the input circuit's qids(), including idle wires.
  fn after_gate(Self, Gate, ArrayView[Int32]) -> Array[(Channel, Array[Int32])] raise CircuitError
}
