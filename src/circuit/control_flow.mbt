///|
/// A classical condition and the two instruction sequences it selects between.
/// The branch bodies capture the circuits as they were when if_else was called.
struct IfElse[Q] {
  condition : &Condition
  on_true : Array[Instruction[Q]]
  on_false : Array[Instruction[Q]]
  names : Array[String]
  width : Int32
}

///|
/// Evaluate the condition once and iterate the selected arm in circuit order.
pub fn[Q] IfElse::select(
  self : IfElse[Q],
  record : &MeasurementRecord,
) -> Iter[Instruction[Q]] raise CircuitError {
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
/// A counted loop captures its body at construction. 
struct ForLoop[Q] {
  count : Int32
  body : Array[Instruction[Q]]
  names : Array[String]
  width : Int32
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
/// A measurement-controlled loop captures its body once. The iteration bound
/// determines how many measurement columns the loop reserves in each shot.
struct WhileLoop[Q] {
  condition : &Condition
  max_iterations : Int32
  body : Array[Instruction[Q]]
  names : Array[String]
  width : Int32
}

///|
pub fn[Q] WhileLoop::condition(self : WhileLoop[Q]) -> &Condition {
  self.condition
}

///|
pub fn[Q] WhileLoop::max_iterations(self : WhileLoop[Q]) -> Int32 {
  self.max_iterations
}

///|
/// Iterate over one copy of the body in execution order.
pub fn[Q] WhileLoop::body(self : WhileLoop[Q]) -> Iter[Instruction[Q]] {
  self.body.iter()
}
