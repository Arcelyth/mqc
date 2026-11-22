///|
/// A circuit operation bound to distinct, ordered quantum IDs.
struct Operation[Q] {
  effect : &Effect
  wires : Array[Q]
}

///|
pub fn[Q : Qid] Operation::new(
  effect : &Effect,
  targets : Array[Q],
) -> Operation[Q] raise @error.QError {
  let shape = effect.dim()
  if shape.length() != targets.length() {
    raise TargetCount(shape.length(), targets.length())
  }
  let seen : Map[Q, Bool] = Map([])
  for i, q in targets {
    if seen.contains(q) {
      raise DuplicateQid(i)
    }
    seen[q] = true
    let actual = q.dim()
    let expected = shape[i]
    if actual != expected {
      raise DimensionMismatch(i, expected, actual)
    }
  }
  { effect, wires: targets.copy(), }
}

///|
/// Applies a classical condition to this operation.
/// The operation executes only when the condition evaluates to true.
pub fn[Q] Operation::when(
  self : Operation[Q],
  conditions : &Condition,
) -> Operation[Q] raise @error.QError {
  if self.effect.measurement_key() is Some(_) {
    raise InvalidCondition("measurements must execute on every shot")
  }
  {
    ..self,
    effect: ConditionalEffect::{ condition: conditions, inner: self.effect, },
  }
}

///|
/// Return the effect's direct unitary capability, if present.
pub fn[Q] Operation::gate(self : Operation[Q]) -> Gate? {
  self.effect.try_unitary()
}

///|
pub fn[Q] Operation::effect(self : Operation[Q]) -> &Effect {
  self.effect
}

///|
/// Return a copy of the logical targets in effect wire order.
pub fn[Q] Operation::targets(self : Operation[Q]) -> Array[Q] {
  self.wires.copy()
}

///|
pub impl[Q : Debug] Debug for Operation[Q] with fn to_repr(self) {
  Debug::to_repr((self.effect.name(), self.wires))
}

///|
pub extend Operation with Debug::{to_repr}
