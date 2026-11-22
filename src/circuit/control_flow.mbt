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
  let merged = self.concat(joined)
  self.wires = merged.wires
  self.shape = merged.shape
  self.indices = merged.indices
  self.parameter_names = merged.parameter_names
  self.ops = self.ops.push(IfElse(branch))
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
/// Number of columns this instruction occupies in a shot. Both arms of a
/// branch start at the same column and reserve space for the wider arm.
pub fn[Q] Instruction::record_width(self : Instruction[Q]) -> Int32 {
  match self {
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
