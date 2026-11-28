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
  body : Array[Instruction[Q]],
  map : (Q) -> R,
) -> Array[Instruction[R]] {
  body.map(instruction => instruction.map_wires(map))
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

///|
fn[Q] Instruction::collect_symbols(
  self : Instruction[Q],
  symbols : Map[Parameter, Unit],
) -> Unit {
  match self {
    Operation(op) =>
      for param in op.effect.parameter_symbols() {
        symbols[param] = ()
      }
    IfElse(branch) => {
      for instruction in branch.on_true {
        instruction.collect_symbols(symbols)
      }
      for instruction in branch.on_false {
        instruction.collect_symbols(symbols)
      }
    }
    ForLoop(block) if block.count > 0 =>
      for instruction in block.body {
        instruction.collect_symbols(symbols)
      }
    WhileLoop(block) if block.max_iterations > 0 =>
      for instruction in block.body {
        instruction.collect_symbols(symbols)
      }
    _ => ()
  }
}

///|
fn[Q] Instruction::parameter_symbols(self : Instruction[Q]) -> Array[Parameter] {
  if self is Operation(op) {
    return op.effect.parameter_symbols()
  }
  let symbols = Map([])
  self.collect_symbols(symbols)
  symbols.keys().collect()
}

///|
fn[Q] Instruction::assign_parameters(
  self : Instruction[Q],
  bindings : Map[Parameter, ParamExpr],
) -> Instruction[Q] raise {
  match self {
    Operation(op) => Operation(op.assign_parameters(bindings))
    IfElse(branch) => {
      let on_true = assign_instructions(branch.on_true, bindings)
      let on_false = assign_instructions(branch.on_false, bindings)
      let names = instruction_parameter_names(
        on_true.iter().concat(on_false.iter()),
      )
      IfElse({ ..branch, on_true, on_false, names, })
    }
    ForLoop(block) => {
      let body = assign_instructions(block.body, bindings)
      ForLoop({
        ..block,
        body,
        names: instruction_parameter_names(body.iter()),
      })
    }
    WhileLoop(block) => {
      let body = assign_instructions(block.body, bindings)
      WhileLoop({
        ..block,
        body,
        names: instruction_parameter_names(body.iter()),
      })
    }
  }
}

///|
fn[Q] assign_instructions(
  body : Array[Instruction[Q]],
  bindings : Map[Parameter, ParamExpr],
) -> Array[Instruction[Q]] raise {
  body.map(instruction => {
    if instruction
      .parameter_symbols()
      .iter()
      .any(param => bindings.contains(param)) {
      instruction.assign_parameters(bindings)
    } else {
      instruction
    }
  })
}

///|
fn[Q] instruction_parameter_names(
  instructions : Iter[Instruction[Q]],
) -> Array[String] {
  let mut names = @hashset.empty()
  for instruction in instructions {
    for name in instruction.parameters() {
      names = names.insert(name)
    }
  }
  let ordered = names.iter().collect()
  ordered.sort_by(String::lexical_compare)
  ordered
}

///|
/// Number of columns this instruction occupies in a shot.
/// Both arms of a branch start at the same column and reserve space for the wider arm.
pub fn[Q] Instruction::record_width(self : Instruction[Q]) -> Int32 {
  match self {
    WhileLoop(block) => block.width
    ForLoop(loop_body) => loop_body.width
    IfElse(branch) => branch.width
    Operation(op) if op.effect.measurement_key() is Some(_) => op.wires.length()
    Operation(_) => 0
  }
}
