///|
#derive(Eq)
pub struct Shape {
  dimensions : Array[UInt32]
}

///|
pub fn Shape::new(dimensions : Array[UInt32]) -> Shape {
  { dimensions: dimensions.copy(), }
}

///|
#inline
pub fn Shape::size(self : Shape) -> Int32 {
  self.dimensions.fold(init=1, (size, dimension) => {
    size * dimension.reinterpret_as_int()
  })
}

///|
pub fn Shape::length(self : Shape) -> Int32 {
  self.dimensions.length()
}

///|
#alias(op_get)
pub fn Shape::get(self : Shape, index : Int32) -> UInt32 {
  self.dimensions[index]
}

///|
pub fn Shape::to_array(self : Shape) -> Array[UInt32] {
  self.dimensions.copy()
}

///|
pub fn Shape::strides(self : Shape) -> Array[Int32] {
  let strides = Array::make(self.length(), 1)
  let mut stride = 1
  for i = self.length() - 1; i >= 0; i = i - 1 {
    strides[i] = stride
    stride *= self[i].reinterpret_as_int()
  }
  strides
}

///|
pub extend Shape with Eq::{equal, not_equal}
