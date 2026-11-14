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
  fn dimension(Self) -> Int32
  /// Apply U * input using the KernelArgs.
  fn apply(Self, KernelArgs) -> Unit
  /// Return an immutable kernel for U† on the same dimension.
  fn adjoint(Self) -> &UnitaryKernel
}

///|
/// Kernel that applies a general dense unitary matrix.
/// Stores the matrix in row-major order.
priv struct DenseKernel {
  data : Array[@maths.Complex]
  size : Int32
}

// ===== Implement UnitaryKernel for DenseKernel =====

///|
impl UnitaryKernel for DenseKernel with fn dimension(self) -> Int32 {
  self.size
}

///|
/// Multiply the row-order unitary matrix by the local input and write all outputs.
impl UnitaryKernel for DenseKernel with fn apply(self, args) {
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
impl UnitaryKernel for DenseKernel with fn adjoint(self) -> &UnitaryKernel {
  let data = Array::makei(self.data.length(), fn(i) {
    self.data[i % self.size * self.size + i / self.size].conjugate()
  })
  DenseKernel::{ data, size: self.size, }
}

// ===== ===== 

// ===== Implement UnitaryKernel for MonomialKernel =====

///|
/// Represents a matrix with exactly one nonzero entry in each row and column.
/// For example, Pauli Y: 
/// Y= [ 0  -i ]
///    [ i  0  ]
///    
/// columns = [1, 0]
/// phases  = [-i, i]
priv struct MonomialKernel {
  columns : Array[Int32]
  phases : Array[@maths.Complex]
}

///|
impl UnitaryKernel for MonomialKernel with fn dimension(self) -> Int32 {
  self.columns.length()
}

///|
/// Permute local inputs and multiply by one phase per output row.
impl UnitaryKernel for MonomialKernel with fn apply(self, args) {
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
impl UnitaryKernel for MonomialKernel with fn adjoint(self) -> &UnitaryKernel {
  let columns = Array::make(self.columns.length(), 0)
  let phases = Array::make(self.columns.length(), @maths.Complex::real(0.0))
  for row, col in self.columns {
    columns[col] = row
    phases[col] = self.phases[row].conjugate()
  }
  MonomialKernel::{ columns, phases, }
}

// ===== =====

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
