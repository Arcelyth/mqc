///|
/// A circuit instruction uses logical wire IDs before compilation and integer
/// wire indices afterwards. Only a quantum operation has target wires.
pub enum Instruction[Q] {
  Operation(Operation[Q])
  IfElse(IfElse[Q])
  ForLoop(ForLoop[Q])
  WhileLoop(WhileLoop[Q])
}

///|
fn[Q, R] Instruction::map_wires(
  self : Instruction[Q],
  map : (Q) -> R,
) -> Instruction[R] {
  match self {
    Operation(op) => Operation({ effect: op.effect, wires: op.wires.map(map), })
    WhileLoop(block) =>
      WhileLoop({
        condition: block.condition,
        max_iterations: block.max_iterations,
        body: map_instructions(block.body, map),
        names: block.names,
        width: block.width,
      })
    ForLoop(block) =>
      ForLoop({
        count: block.count,
        body: map_instructions(block.body, map),
        names: block.names,
        width: block.width,
      })
    IfElse(branch) =>
      IfElse({
        condition: branch.condition,
        on_true: map_instructions(branch.on_true, map),
        on_false: map_instructions(branch.on_false, map),
        names: branch.names,
        width: branch.width,
      })
  }
}

///|
fn[Q, R] map_instructions(
  body : @vector.Vector[Instruction[Q]],
  map : (Q) -> R,
) -> @vector.Vector[Instruction[R]] {
  let mut result = @vector.Vector::new()
  for instruction in body {
    result = result.push(instruction.map_wires(map))
  }
  result
}

///|
pub fn[Q] Instruction::parameters(self : Instruction[Q]) -> Array[String] {
  match self {
    Operation(op) => op.effect.parameters()
    WhileLoop(block) => block.names.copy()
    ForLoop(block) => block.names.copy()
    IfElse(branch) => branch.names.copy()
  }
}
