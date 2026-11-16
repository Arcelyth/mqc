///|
/// Kernel that applies a general dense unitary matrix.
/// Stores the matrix in row-major order.
pub(all) struct DenseKernel {
  data : Array[@maths.Complex]
  size : Int32
}

///|
pub impl UnitaryKernel for DenseKernel with fn size(self) -> Int32 {
  self.size
}

///|
/// Multiply the row-order unitary matrix by the local input and write all outputs.
pub impl UnitaryKernel for DenseKernel with fn apply(self, args) {
  for row in 0..<self.size {
    let mut re = 0.0
    let mut im = 0.0
    for col in 0..<self.size {
      let value = self.data[row * self.size + col]
      re += value.re * args.input_re[col] - value.im * args.input_im[col]
      im += value.re * args.input_im[col] + value.im * args.input_re[col]
    }
    args.output_re[row] = re
    args.output_im[row] = im
  }
}

///|
pub impl UnitaryKernel for DenseKernel with fn adjoint(self) -> &UnitaryKernel {
  let data = Array::makei(self.data.length(), fn(i) {
    self.data[i % self.size * self.size + i / self.size].conjugate()
  })
  DenseKernel::{ data, size: self.size, }
}

///|
pub extend DenseKernel with UnitaryKernel::{size, apply, adjoint}
