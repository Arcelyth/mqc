///|
pub(all) struct KernelArgs {}

///

///|
/// A pure, linear, unitary map on a local state vector.
pub(open) trait UnitaryKernel {
  fn dimension(Self) -> Int32
  fn apply(Self, KernelArgs) -> Unit
}
