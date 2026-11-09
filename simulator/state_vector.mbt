/// A quantum state represented by a complex state vector.
///
/// For example, a two-qubit state |ψ⟩ = (|00⟩ + |11⟩) / √2:
///
///   shape = [2, 2]
///   re    = [1/√2, 0, 0, 1/√2]
///   im    = [0,    0, 0, 0]
///
/// The entries are stored in basis-state order:
///   |00⟩, |01⟩, |10⟩, |11⟩.
struct StateVector {
  /// Ordered wire dimensions.
  shape : Array[UInt32]
  /// Real components of the state amplitudes.
  re : Array[Double]
  /// Imaginary components of the state amplitudes.
  im : Array[Double]
}
