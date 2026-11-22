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
/// Iterate over top-level instructions. 
/// With expand_loops=true, yield each iteration in execution order. 
/// Conditional branches remain single instructions.
pub fn Program::instructions(
  self : Program,
  expand_loops~ : Bool = false,
) -> Iter[Instruction[Int32]] {
  if expand_loops {
    expand_counted_loops(self.ops.iter())
  } else {
    self.ops.iter()
  }
}

///|
fn expand_counted_loops(
  body : Iter[Instruction[Int32]],
) -> Iter[Instruction[Int32]] {
  body.flat_map(instruction => {
    match instruction {
      ForLoop(block) =>
        Iter::repeat(block)
        .take(block.count)
        .flat_map(b => expand_counted_loops(b.body.iter()))
      _ => Iter::singleton(instruction)
    }
  })
}
