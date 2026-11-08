///|
pub(all) struct KernelArgs {}

///|
/// A pure, linear, unitary map on a local state vector.
pub(open) trait UnitaryKernel {
  fn dimension(Self) -> Int32
  fn apply(Self, KernelArgs) -> Unit
}

///|
/// Kernel that applies a general dense unitary matrix.
/// Stores the matrix in row-major order.
priv struct DenseKernel {
  data : Array[@maths.Complex]
  size : Int32
}

// ----- Implement UnitaryKernel for DenseKernel -----

///|
impl UnitaryKernel for DenseKernel with fn dimension(self) -> Int32 {
  self.size
}

///|
/// Multiply the row-order unitary matrix by the local input and write all outputs.
impl UnitaryKernel for DenseKernel with fn apply(_self, _args) {

}

// ----- -----

// ----- Implement UnitaryKernel for MonomialKernel -----

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
/// Multiply the row-order unitary matrix by the local input and write all outputs.
impl UnitaryKernel for MonomialKernel with fn apply(_self, _args) {

}

// ----- -----

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
