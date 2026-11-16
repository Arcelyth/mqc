///|
/// Apply a local kernel on one control block and identity on the others.
pub(all) struct ControlledKernel {
  inner : &UnitaryKernel
  size : Int32
  offset : Int32
}

///|
pub impl UnitaryKernel for ControlledKernel with fn size(self) -> Int32 {
  self.size
}

///|
pub impl UnitaryKernel for ControlledKernel with fn apply(self, args) -> Unit {
  for i in 0..<self.size {
    args.output_re[i] = args.input_re[i]
    args.output_im[i] = args.input_im[i]
  }
  let end = self.offset + self.inner.size()
  self.inner.apply({
    input_re: args.input_re[self.offset:end],
    input_im: args.input_im[self.offset:end],
    output_re: args.output_re.mut_view(start=self.offset, end~),
    output_im: args.output_im.mut_view(start=self.offset, end~),
  })
}

///|
pub impl UnitaryKernel for ControlledKernel with fn adjoint(self) -> &UnitaryKernel {
  ControlledKernel::{
    inner: self.inner.adjoint(),
    size: self.size,
    offset: self.offset,
  }
}

///|
pub extend ControlledKernel with UnitaryKernel::{size, apply, adjoint}
