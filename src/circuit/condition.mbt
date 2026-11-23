///|
/// Measurement results available to a condition during one shot. Digits are
/// returned in target order. 
/// Reading a key before its measurement raises `InvalidCondition`.
pub(open) trait MeasurementRecord {
  fn latest(Self, String) -> ArrayView[Int32] raise @error.QError
}

///|
/// A predicate over the current shot. 
/// Implement this trait to compare digits across keys 
/// or to supply a different rule for selecting a branch.
pub(open) trait Condition {
  fn evaluate(Self, &MeasurementRecord) -> Bool raise @error.QError
  fn name(Self) -> String = _
}

///|
impl Condition with fn name(_) {
  "condition"
}

///|
/// Combine named measurement tests with Boolean operators.
pub(all) enum MeasurementCondition {
  Nonzero(String)
  And(&Condition, &Condition)
  Or(&Condition, &Condition)
  Not(&Condition)
}

///|
pub impl Condition for MeasurementCondition with fn evaluate(self, records) {
  match self {
    Nonzero(key) => records.latest(key).iter().any(digit => digit != 0)
    And(left, right) => left.evaluate(records) && right.evaluate(records)
    Or(left, right) => left.evaluate(records) || right.evaluate(records)
    Not(inner) => !inner.evaluate(records)
  }
}

///|
pub impl Condition for MeasurementCondition with fn name(self) {
  match self {
    Nonzero(key) => key.escape() + " != 0"
    And(left, right) => "(" + left.name() + " and " + right.name() + ")"
    Or(left, right) => "(" + left.name() + " or " + right.name() + ")"
    Not(inner) => "not (" + inner.name() + ")"
  }
}

///|
/// Chained when calls are unwrapped outermost first. Evaluate them in the
/// original order, including later predicates when an earlier one is false.
pub(all) struct ChainedCondition(Array[&Condition])

///|
impl Condition for ChainedCondition with fn evaluate(self, record) {
  let mut enabled = true
  for i = self.0.length() - 1; i >= 0; i = i - 1 {
    let passes = self.0[i].evaluate(record)
    enabled = enabled && passes
  }
  enabled
}

///|
/// Execute the inner effect only when the measurement satisfies the condition.
pub struct ConditionalEffect {
  inner : &Effect
  condition : &Condition
}

///|
pub impl Effect for ConditionalEffect with fn name(self) {
  self.inner.name() + " when " + self.condition.name()
}

///|
pub impl Effect for ConditionalEffect with fn dim(self) {
  self.inner.dim()
}

///|
pub impl Effect for ConditionalEffect with fn parameters(self) {
  self.inner.parameters()
}

///|
pub impl Effect for ConditionalEffect with fn try_conditional(self) {
  Some(self)
}

///|
pub extend MeasurementCondition with Condition::{name, evaluate}

///|
pub extend ConditionalEffect with Effect::{
  name,
  dim,
  arity,
  measurement_key,
  try_conditional,
  try_unitary,
  try_channel,
  try_decompose,
  try_adjoint,
  parameters,
}
