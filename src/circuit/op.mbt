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
) -> Operation[Q] raise CircuitError {
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
) -> Operation[Q] raise CircuitError {
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
fn[Q] Operation::assign_parameters(
  self : Operation[Q],
  bindings : Map[Parameter, ParamExpr],
) -> Operation[Q] raise {
  let effect = self.effect.assign_parameters(bindings)
  if effect.dim() != self.effect.dim() ||
    effect.measurement_key() != self.effect.measurement_key() {
    raise InvalidGate(
      "assigning parameters changed the effect's dimensions or measurement key",
    )
  }
  { ..self, effect, }
}

///|
pub impl[Q : Debug] Debug for Operation[Q] with fn to_repr(self) {
  Debug::to_repr((self.effect.name(), self.wires))
}

///|
pub extend Operation with Debug::{to_repr}

///|
fn[Q : Qid] Operation::draw_column(
  self : Operation[Q],
  rows : Array[StringBuilder],
  wires : Registry[Q],
) -> Unit {
  let (label, measurement) = match self.effect.measurement_key() {
    Some(key) => ("M(\{key.escape()})", true)
    None => (self.effect.name(), false)
  }
  let symbols : Map[Int32, String] = Map([])
  let mut width = label.length()
  for index, wire in self.wires {
    let symbol = if index == 0 {
      label
    } else if measurement {
      "M"
    } else {
      "#\{index + 1}"
    }
    symbols[wires.index(wire)] = symbol
    width = width.max(symbol.length())
  }
  for wire, row in rows {
    row.write_string(symbols.get_or_default(wire, "").pad_end(width + 3, '─'))
  }
}
