///|
pub using @kernel {
  trait UnitaryKernel,
  type KernelArgs,
  type DenseKernel,
  type MonomialKernel,
  type ControlledKernel,
}

///|
/// Select a kernel based on the matrix's sparsity structure.
/// Use MonomialKernel when each row contains exactly one nonzero entry;
/// otherwise, fall back to DenseKernel.
/// Only exact zeros are considered, preserving all nonzero entries.
fn matrix_kernel(data : Array[@maths.Complex], size : Int32) -> &UnitaryKernel {
  let columns = Array::make(size, -1)
  let phases = Array::make(size, @maths.Complex::real(0.0))
  for row in 0..<size {
    for col in 0..<size {
      let value = data[row * size + col]
      if value.re != 0.0 || value.im != 0.0 {
        if columns[row] >= 0 {
          return DenseKernel::{ data, size, }
        }
        columns[row] = col
        phases[row] = value
      }
    }
    if columns[row] < 0 {
      return DenseKernel::{ data, size, }
    }
  }
  MonomialKernel::{ columns, phases, }
}
