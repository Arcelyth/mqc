///|
/// A classical condition and the two instruction sequences it selects between.
/// The branch bodies capture the circuits as they were when if_else was called.
struct IfElse[Q] {
  condition : &Condition
  on_true : @vector.Vector[Instruction[Q]]
  on_false : @vector.Vector[Instruction[Q]]
  names : Array[String]
  width : Int32
}

///|
/// Append a branch to this circuit. Evaluate the condition once on entry,
/// execute the selected circuit, then continue after the branch. Either body
/// can be empty. Measurements in the selected body update the shot's record.
pub fn[Q : Qid] Circuit::if_else(
  self : Circuit[Q],
  condition : &Condition,
  on_true : Circuit[Q],
  on_false : Circuit[Q],
) -> Unit raise @error.QError {
  let joined = on_true.concat(on_false)
  let names = joined.parameter_names.iter().collect()
  names.sort_by(String::lexical_compare)
  let branch = IfElse::{
    condition,
    on_true: on_true.ops,
    on_false: on_false.ops,
    names,
    width: on_true.record_width().max(on_false.record_width()),
  }
  self.append_block(joined, IfElse(branch))
}

///|
/// Evaluate the condition once and iterate the selected arm in circuit order.
pub fn[Q] IfElse::select(
  self : IfElse[Q],
  record : &MeasurementRecord,
) -> Iter[Instruction[Q]] raise @error.QError {
  if self.condition.evaluate(record) {
    self.on_true.iter()
  } else {
    self.on_false.iter()
  }
}

///|
pub fn[Q] IfElse::condition(self : IfElse[Q]) -> &Condition {
  self.condition
}

///|
pub fn[Q] IfElse::on_true(self : IfElse[Q]) -> Iter[Instruction[Q]] {
  self.on_true.iter()
}

///|
pub fn[Q] IfElse::on_false(self : IfElse[Q]) -> Iter[Instruction[Q]] {
  self.on_false.iter()
}

///|
/// Number of columns this instruction occupies in a shot. 
/// Both arms of a branch start at the same column and reserve space for the wider arm.
pub fn[Q] Instruction::record_width(self : Instruction[Q]) -> Int32 {
  match self {
    ForLoop(loop_body) => loop_body.width
    IfElse(branch) => branch.width
    Operation(op) if op.effect.measurement_key() is Some(_) => op.wires.length()
    Operation(_) => 0
  }
}

///|
fn[Q] Circuit::record_width(self : Circuit[Q]) -> Int32 raise @error.QError {
  let mut width = 0
  for instruction in self.instructions() {
    let count = instruction.record_width()
    if count > 2147483647 - width {
      raise SizeLimit(2147483647)
    }
    width += count
  }
  width
}

///|
/// A counted loop captures its body at construction. 
struct ForLoop[Q] {
  count : Int32
  body : @vector.Vector[Instruction[Q]]
  names : Array[String]
  width : Int32
}

///|
/// Append a loop that executes the body exactly count times on the same state.
/// Each measurement appends its digits in iteration order. A count of zero
/// skips the body. A negative count raises InvalidState.
pub fn[Q : Qid] Circuit::for_loop(
  self : Circuit[Q],
  count : Int32,
  body : Circuit[Q],
) -> Unit raise @error.QError {
  if count < 0 {
    raise InvalidState("loop count must be nonnegative")
  }
  let names : Array[String] = []
  let mut width = 0
  if count > 0 {
    let per_iteration = body.record_width()
    if per_iteration > 2147483647 / count {
      raise SizeLimit(2147483647)
    }
    width = per_iteration * count
    for name in body.parameter_names.iter() {
      names.push(name)
    }
    names.sort_by(String::lexical_compare)
  }
  self.append_block(body, ForLoop({ count, body: body.ops, names, width, }))
}

///|
pub fn[Q] ForLoop::count(self : ForLoop[Q]) -> Int32 {
  self.count
}

///|
/// Iterate over the instructions of one iteration.
pub fn[Q] ForLoop::body(self : ForLoop[Q]) -> Iter[Instruction[Q]] {
  self.body.iter()
}

///|
fn[Q : Qid] Circuit::append_block(
  self : Circuit[Q],
  body : Circuit[Q],
  instruction : Instruction[Q],
) -> Unit raise @error.QError {
  let merged = self.concat(body)
  self.wires = merged.wires
  self.shape = merged.shape
  self.indices = merged.indices
  self.parameter_names = add_names(
    self.parameter_names,
    instruction.parameters(),
  )
  self.ops = self.ops.push(instruction)
}
