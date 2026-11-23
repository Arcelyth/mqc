///|
/// A matrix with exactly one nonzero entry in each row and column.
/// For Pauli Y, the column indices are 1 and 0, in row order.
///
/// $$
/// Y = \begin{bmatrix}0 & -i \\ i & 0\end{bmatrix},\qquad \mathrm{phases}=(-i,i).
/// $$
pub(all) struct MonomialKernel {
  columns : Array[Int32]
  phases : Array[@maths.Complex]
}

///|
pub impl LinearKernel for MonomialKernel with fn size(self) -> Int32 {
  self.columns.length()
}

///|
/// Permute local inputs and multiply by one phase per output row.
pub impl LinearKernel for MonomialKernel with fn apply(self, args) {
  for row, col in self.columns {
    let value = self.phases[row]
    args.output_re[row] = value.re * args.input_re[col] -
      value.im * args.input_im[col]
    args.output_im[row] = value.re * args.input_im[col] +
      value.im * args.input_re[col]
  }
}

///|
/// Invert the permutation and conjugate its phases.
pub impl UnitaryKernel for MonomialKernel with fn adjoint(self) -> &UnitaryKernel {
  let columns = Array::make(self.columns.length(), 0)
  let phases = Array::make(self.columns.length(), @maths.Complex::real(0.0))
  for row, col in self.columns {
    columns[col] = row
    phases[col] = self.phases[row].conjugate()
  }
  MonomialKernel::{ columns, phases, }
}

///|
pub extend MonomialKernel with LinearKernel::{size, apply}

///|
pub extend MonomialKernel with UnitaryKernel::{adjoint}
