///|
struct Program {
  label : String
  shape : @internal.Shape
  ops : @vector.Vector[Instruction[Int32]]
}

///|
pub fn Program::dim(self : Program) -> Array[UInt32] {
  self.shape.to_array()
}

///|
pub fn Program::name(self : Program) -> String {
  self.label
}

///|
pub fn Program::length(self : Program) -> Int32 {
  self.ops.length()
}

///|
pub fn Program::shape(self : Program) -> @internal.Shape {
  self.shape
}

///|
pub fn Program::instructions(self : Program) -> Iter[Instruction[Int32]] {
  self.ops.iter()
}
