///|
pub(all) struct KernelArgs {
  /// Real parts of the local input, in basis or matrix-entry order.
  input_re : ArrayView[Double]
  /// Imaginary parts, with the same length and ordering as input_re.
  input_im : ArrayView[Double]
  /// Real parts of the complete result; every entry must be written.
  output_re : MutArrayView[Double]
  /// Imaginary parts of the complete result; every entry must be written.
  output_im : MutArrayView[Double]
}

///|
/// A pure, linear, unitary map on a local state vector.
pub(open) trait UnitaryKernel {
  fn size(Self) -> Int32
  /// Apply U * input using the KernelArgs.
  fn apply(Self, KernelArgs) -> Unit
  /// Return an immutable kernel for U† on the same dimension.
  fn adjoint(Self) -> &UnitaryKernel
}
