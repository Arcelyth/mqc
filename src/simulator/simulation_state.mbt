///|
/// Mutable backend state. Copies must own independent mutable storage.
pub(open) trait SimulationState {
  fn dim(Self) -> Array[UInt32]
  /// Execute one compiled instruction and update this state in place.
  /// The backend owns any RNG needed by random instructions.
  fn apply(Self, @circuit.Instruction) -> Unit raise @error.QError
  /// Copy the state and its measurement history into independent storage.
  fn copy(Self) -> Self
  /// Return an independent copy of the measurement records so far.
  fn records(Self) -> @maths.Array3[Int32]
  /// Check the backend's state invariants.
  fn validate(Self) -> Unit raise @error.QError
}
