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
