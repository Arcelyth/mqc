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
/// A linear map from a local complex vector to one of the same size.
pub(open) trait LinearKernel {
  /// Returns the dimension of the linear operator.
  fn size(Self) -> Int32
  /// Applies the linear transformation to the input state.
  fn apply(Self, KernelArgs) -> Unit
}

///|
/// A linear kernel that preserves inner products.
pub(open) trait UnitaryKernel: LinearKernel {
  /// Returns the adjoint (conjugate transpose) of this unitary operator.
  ///
  /// For a unitary kernel, the adjoint is equivalent to its inverse.
  fn adjoint(Self) -> &UnitaryKernel
}
