///|
/// Apply the inner linear kernel and multiply each output by a real scalar.
///
/// $$
/// y = s K x
/// $$
pub(all) struct ScaledKernel {
  inner : &LinearKernel
  scale : Double
}

///|
pub impl LinearKernel for ScaledKernel with fn size(self) {
  self.inner.size()
}

///|
pub impl LinearKernel for ScaledKernel with fn apply(self, args) {
  self.inner.apply(args)
  for i in 0..<self.inner.size() {
    args.output_re[i] *= self.scale
    args.output_im[i] *= self.scale
  }
}

///|
pub extend ScaledKernel with LinearKernel::{size, apply}
