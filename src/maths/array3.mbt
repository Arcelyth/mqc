///|
/// A mutable, fixed-shape three-dimensional array with contiguous storage.
/// Coordinates (i, j, k) map to (i * dim1 + j) * dim2 + k.
struct Array3[T] {
  dim0 : Int32
  dim1 : Int32
  dim2 : Int32
  data : FixedArray[T]
}

///|
/// Validate dimensions before multiplication or allocation.
#inline
fn array3_length(dim0 : Int32, dim1 : Int32, dim2 : Int32) -> Int32 {
  if dim0 < 0 || dim1 < 0 || dim2 < 0 {
    abort("Array3: dimensions must be nonnegative")
  }
  if dim0 == 0 || dim1 == 0 || dim2 == 0 {
    return 0
  }
  let max_length = 2147483647
  if dim0 > max_length / dim1 {
    abort("Array3: element count exceeds Int32 capacity")
  }
  let plane_count = dim0 * dim1
  if plane_count > max_length / dim2 {
    abort("Array3: element count exceeds Int32 capacity")
  }
  plane_count * dim2
}

///|
/// Create an array filled with the supplied value. Zero dimensions are valid.
/// Aborts for negative dimensions or an element count exceeding Int32 capacity.
/// Like Array::make, mutable element values are shared; use makei for fresh values.
pub fn[T] Array3::make(
  dim0 : Int32,
  dim1 : Int32,
  dim2 : Int32,
  value : T,
) -> Array3[T] {
  let length = array3_length(dim0, dim1, dim2)
  { dim0, dim1, dim2, data: FixedArray::make(length, value), }
}

///|
/// Initialize each coordinate once, in row-major order (last axis fastest).
/// Empty arrays do not invoke init.
pub fn[T] Array3::makei(
  dim0 : Int32,
  dim1 : Int32,
  dim2 : Int32,
  init : (Int32, Int32, Int32) -> T,
) -> Array3[T] {
  let length = array3_length(dim0, dim1, dim2)
  let data = FixedArray::makei(length, fn(index) {
    let k = index % dim2
    let row = index / dim2
    init(row / dim1, row % dim1, k)
  })
  { dim0, dim1, dim2, data, }
}

///|
pub fn[T] Array3::shape(self : Array3[T]) -> (Int32, Int32, Int32) {
  (self.dim0, self.dim1, self.dim2)
}

///|
pub fn[T] Array3::length(self : Array3[T]) -> Int32 {
  self.data.length()
}

///|
/// Check each axis independently before flattening the coordinates.
fn[T] Array3::offset(
  self : Array3[T],
  i : Int32,
  j : Int32,
  k : Int32,
) -> Int32? {
  if i < 0 ||
    i >= self.dim0 ||
    j < 0 ||
    j >= self.dim1 ||
    k < 0 ||
    k >= self.dim2 {
    None
  } else {
    Some((i * self.dim1 + j) * self.dim2 + k)
  }
}

///|
/// Read an element, or return None if any coordinate is out of bounds.
pub fn[T] Array3::get(self : Array3[T], i : Int32, j : Int32, k : Int32) -> T? {
  match self.offset(i, j, k) {
    Some(index) => Some(self.data[index])
    None => None
  }
}

///|
/// Write an element. Return false without mutation if any coordinate is invalid.
pub fn[T] Array3::set(
  self : Array3[T],
  i : Int32,
  j : Int32,
  k : Int32,
  value : T,
) -> Bool {
  match self.offset(i, j, k) {
    Some(index) => {
      self.data[index] = value
      true
    }
    None => false
  }
}

///|
/// Copy the backing storage and shape. Elements themselves are shallow-copied.
pub fn[T] Array3::copy(self : Array3[T]) -> Array3[T] {
  { dim0: self.dim0, dim1: self.dim1, dim2: self.dim2, data: self.data.copy(), }
}

///|
/// Export an independent flat row-major array. Elements are shallow-copied.
pub fn[T] Array3::to_array(self : Array3[T]) -> Array[T] {
  Array::from_fixed_array(self.data)
}
