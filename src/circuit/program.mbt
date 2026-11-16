///|
/// A checked binding to ordered local wire indices.
struct Instruction {
  effect_value : &Effect
  wires : Array[Int32]
}

///|
pub fn Instruction::effect(self : Instruction) -> &Effect {
  self.effect_value
}

///|
pub fn Instruction::targets(self : Instruction) -> Array[Int32] {
  self.wires.copy()
}

///|
struct Program {
  label : String
  shape : @internal.Shape
  ops : @vector.Vector[Instruction]
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
pub fn Program::instructions(self : Program) -> Iter[Instruction] {
  self.ops.iter()
}
