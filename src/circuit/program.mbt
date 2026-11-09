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
  shape : Array[UInt32]
  ops : @vector.Vector[Instruction]
}

///|
pub fn Program::dimensions(self : Program) -> Array[UInt32] {
  self.shape.copy()
}

///|
pub fn Program::name(self : Program) -> String {
  self.label
}

///|
pub fn Program::length(self : Program) -> Int32 {
  self.ops.length()
}
