///|
/// An effect bound to distinct, ordered quantum IDs.
struct Operation[Q] {
  effect : &Effect
  wires : Array[Q]
}

///|
pub fn[Q : Qid] Operation::new(
  effect : &Effect,
  targets : Array[Q],
) -> Operation[Q] raise QuantumError {
  let shape = effect.dimensions()
  if shape.length() != targets.length() {
    raise TargetCount(shape.length(), targets.length())
  }
  let seen : Map[Q, Bool] = Map([])
  for i, q in targets {
    if seen.contains(q) {
      raise DuplicateQid(i)
    }
    seen[q] = true
    let actual = q.dimension()
    let expected = shape[i]
    if actual != expected {
      raise DimensionMismatch(i, expected, actual)
    }
  }
  { effect, wires: targets.copy(), }
}

///|
/// Return the effect's direct unitary capability, if present.
pub fn[Q] Operation::gate(self : Operation[Q]) -> Gate? {
  self.effect.try_unitary()
}

///|
/// Return the immutable effect bound by this operation.
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
