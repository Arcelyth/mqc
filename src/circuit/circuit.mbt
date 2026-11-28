///|
/// A quantum circuit and its ordered instruction sequence.
struct Circuit[Q] {
  /// Logical wire identifiers in basis order.
  mut wires : Registry[Q]
  /// Instruction sequence in execution order.
  ops : Array[Instruction[Q]]
  /// The union of names from every effect in current circuit.
  mut parameter_names : @hashset.HashSet[String]
}

///|
/// Create an empty circuit over an ordered list of distinct logical IDs.
pub fn[Q : Qid] Circuit::new(qids : Array[Q]) -> Circuit[Q] raise CircuitError {
  { wires: Registry::new(qids), ops: [], parameter_names: @hashset.empty(), }
}

///|
/// Build a circuit from bound operations in execution order.
pub fn[Q : Qid] Circuit::from_op(
  operations : Array[Operation[Q]],
) -> Circuit[Q] raise CircuitError {
  let circuit = Circuit::new([])
  circuit.extend_ops(operations)
  circuit
}

///|
/// Copy this circuit.
pub fn[Q] Circuit::copy(self : Circuit[Q]) -> Circuit[Q] {
  {
    wires: self.wires,
    ops: self.ops.copy(),
    parameter_names: self.parameter_names,
  }
}

///|
/// Append an operation in place.
pub fn[Q : Qid] Circuit::append(
  self : Circuit[Q],
  operation : Operation[Q],
) -> Unit raise CircuitError {
  self.extend_ops([operation])
}

///|
/// Append a list of operations in place, in the supplied order.
pub fn[Q : Qid] Circuit::extend_ops(
  self : Circuit[Q],
  operations : Array[Operation[Q]],
) -> Unit raise CircuitError {
  let wires = self.wires.with_targets(operations.iter().map(op => op.wires))
  let mut parameter_names = self.parameter_names
  for operation in operations {
    parameter_names = add_names(parameter_names, operation.effect.parameters())
  }
  self.wires = wires
  self.parameter_names = parameter_names
  for operation in operations {
    self.ops.push(Operation(operation))
  }
}

///|
/// Return a copy of the logical IDs in order.
pub fn[Q] Circuit::qids(self : Circuit[Q]) -> Array[Q] {
  self.wires.items.copy()
}

///|
/// Return wire dimensions in basis order.
pub fn[Q : Qid] Circuit::dim(self : Circuit[Q]) -> Array[UInt32] {
  self.wires.dims()
}

///|
/// Iterate over top-level quantum operations. Use instructions() to visit
/// control flow as well.
pub fn[Q] Circuit::operations(self : Circuit[Q]) -> Iter[Operation[Q]] {
  self
  .instructions()
  .filter_map(i => {
    match i {
      Operation(op) => Some(op)
      IfElse(_) | ForLoop(_) | WhileLoop(_) => None
    }
  })
}

///|
/// Iterate over the full sequence, including circuit-level branches.
pub fn[Q] Circuit::instructions(self : Circuit[Q]) -> Iter[Instruction[Q]] {
  let ops = self.ops
  Int32::until(0, ops.length()).map(index => ops[index])
}

///|
/// Count top-level instructions. Each branch occupies one position.
pub fn[Q] Circuit::length(self : Circuit[Q]) -> Int32 {
  self.ops.length()
}

///|
/// Find a logical ID's position. Return `None` if absent.
pub fn[Q : Qid] Circuit::index_of(self : Circuit[Q], qid : Q) -> Int32? {
  self.wires.get(qid)
}

///|
/// Compile circuit to program.
pub fn[Q : Qid] Circuit::compile(
  self : Circuit[Q],
  name~ : String = "circuit",
) -> Program {
  let wires = self.wires
  let ops = self.instructions()
  {
    label: name,
    shape: @internal.Shape::new(wires.dims()),
    ops: ops
    .map(instruction => instruction.map_wires(q => wires.index(q)))
    .collect(),
  }
}

///|
/// Return a new circuit executing self followed by other.
/// Append new wires in order.
pub fn[Q : Qid] Circuit::concat(
  self : Circuit[Q],
  other : Circuit[Q],
) -> Circuit[Q] raise CircuitError {
  {
    wires: self.wires.merge(other.wires),
    ops: self.ops + other.ops,
    parameter_names: self.parameter_names.union(other.parameter_names),
  }
}

///|
/// Map each logical wire once, preserving wire and target order.
pub fn[Q : Qid, R : Qid] Circuit::remap(
  self : Circuit[Q],
  map : (Q) -> R,
) -> Circuit[R] raise CircuitError {
  let registry = self.wires
  let ops = self.instructions()
  let parameter_names = self.parameter_names
  let wires = registry.items.map(map)
  for i, qid in wires {
    let dim = qid.dim()
    let expected = registry.dim_at(i)
    if dim != expected {
      raise DimensionMismatch(i, expected, dim)
    }
  }
  {
    wires: Registry::new(wires),
    ops: ops
    .map(instruction => instruction.map_wires(q => wires[registry.index(q)]))
    .collect(),
    parameter_names,
  }
}

///|
/// Reverse the operation order and replace each effect with its adjoint.
/// Reject effects without an adjoint.
///
/// $$
/// (U_1 U_2 \cdots U_n)^\dagger = U_n^\dagger \cdots U_2^\dagger U_1^\dagger.
/// $$
pub fn[Q : Qid] Circuit::adjoint(
  self : Circuit[Q],
) -> Circuit[Q] raise CircuitError {
  adjoint_body(self.wires.items, self.ops)
}

///|
/// Computes the measurement metadata for repeated circuit execution.
fn[Q] Circuit::loop_metadata(
  self : Circuit[Q],
  count : Int32,
) -> (Array[String], Int32) raise CircuitError {
  let names : Array[String] = []
  let mut width = 0
  if count > 0 {
    let per_iteration = self.record_width()
    if per_iteration > 2147483647 / count {
      raise SizeLimit(2147483647)
    }
    width = per_iteration * count
    for name in self.parameter_names.iter() {
      names.push(name)
    }
    names.sort_by(String::lexical_compare)
  }
  (names, width)
}

///|
/// Return a circuit with the model's noise inserted after each unitary gate.
/// The model visits each original gate once, including gates inside branches
/// and loop bodies. A guarded gate and its noise share one branch decision.
pub fn[Q : Qid] Circuit::with_noise(
  self : Circuit[Q],
  model : &NoiseModel,
) -> Circuit[Q] raise CircuitError {
  self.noisy_body(self.instructions(), self.wires.items, model)
}

///|
fn[Q : Qid] Circuit::noisy_body(
  self : Circuit[Q],
  body : Iter[Instruction[Q]],
  wires : Array[Q],
  model : &NoiseModel,
) -> Circuit[Q] raise CircuitError {
  let result = Circuit::new(wires)
  for instruction in body {
    match instruction {
      Operation(op) => self.append_noisy_gate(result, op, model)
      IfElse(branch) =>
        result.if_else(
          branch.condition,
          self.noisy_body(branch.on_true.iter(), [], model),
          self.noisy_body(branch.on_false.iter(), [], model),
        )
      ForLoop(block) =>
        result.for_loop(
          block.count,
          self.noisy_body(block.body.iter(), [], model),
        )
      WhileLoop(block) =>
        result.while_loop(
          block.condition,
          self.noisy_body(block.body.iter(), [], model),
          max_iterations=block.max_iterations,
        )
    }
  }
  result
}

///|
fn[Q : Qid] Circuit::append_noisy_gate(
  self : Circuit[Q],
  result : Circuit[Q],
  op : Operation[Q],
  model : &NoiseModel,
) -> Unit raise CircuitError {
  let mut effect = op.effect
  let guards = []
  while effect.try_conditional() is Some(guarded) {
    guards.push(guarded.condition)
    effect = guarded.inner
  }
  if !effect.parameters().is_empty() {
    raise InvalidState("resolve gate parameters before applying a noise model")
  }
  guard effect.try_unitary() is Some(gate) else { return result.append(op) }
  let registry = self.wires
  let positions = op.wires.map(q => registry.index(q))
  let noise = model.after_gate(gate, positions[:])
  if noise.is_empty() {
    return result.append(op)
  }
  let ops = [{ ..op, effect, }]
  for (channel, targets) in noise {
    let wires = []
    for target in targets {
      guard registry.at(target) is Some(q) else { raise InvalidBasis(target) }
      wires.push(q)
    }
    ops.push(Operation::new(channel, wires))
  }
  match guards {
    [] => result.extend_ops(ops)
    [condition] =>
      result.if_else(condition, Circuit::from_op(ops), Circuit::new([]))
    _ =>
      result.if_else(
        ChainedCondition(guards),
        Circuit::from_op(ops),
        Circuit::new([]),
      )
  }
}

///|
fn[Q : Qid] adjoint_body(
  wires : Array[Q],
  body : Array[Instruction[Q]],
) -> Circuit[Q] raise CircuitError {
  let result = Circuit::new(wires)
  for i = body.length() - 1; i >= 0; i = i - 1 {
    match body[i] {
      WhileLoop(_) => raise InvalidGate("while_loop has no circuit adjoint")
      IfElse(_) => raise InvalidGate("if_else has no circuit adjoint")
      ForLoop(block) =>
        if block.count > 0 {
          result.for_loop(block.count, adjoint_body([], block.body))
        } else {
          result.ops.push(body[i])
        }
      Operation(operation) => {
        guard operation.effect.try_adjoint() is Some(inverse) else {
          raise InvalidGate("effect has no adjoint: " + operation.effect.name())
        }
        result.append(Operation::new(inverse, operation.wires))
      }
    }
  }
  result
}

///|
/// Draw one row per wire. Numbered markers show the remaining targets of a gate.
/// Inspired by Cirq.
///
/// For the Bell circuit, `println(circuit)` prints this diagram.
///
/// ```text
/// 0: ───H───CNOT───M("bell")───
/// 1: ───────#2─────M───────────
/// ```
pub impl[Q : Qid + Show] Show for Circuit[Q] with fn output(self, logger) {
  let wires = self.wires
  let ops = self.instructions()
  let labels = wires.items.map(wire => Show::to_string(wire))
  let label_width = labels.fold(init=0, (width, label) => {
    width.max(label.length())
  })
  let rows = labels.map(label => {
    let row = StringBuilder()
    row.write_string(label.pad_start(label_width, ' '))
    row.write_string(": ───")
    row
  })
  for instruction in ops {
    match instruction {
      Operation(operation) => operation.draw_column(rows, wires)
      WhileLoop(block) => {
        let label = "while " + block.condition.name()
        for row in rows {
          row.write_string(label + "───")
        }
      }
      ForLoop(block) =>
        for row in rows {
          row.write_string("repeat \{block.count}───")
        }
      IfElse(branch) => {
        let label = "if " + branch.condition.name()
        for row in rows {
          row.write_string(label + "───")
        }
      }
    }
  }
  for wire, row in rows {
    if wire > 0 {
      logger.write_char('\n')
    }
    logger.write_string(row.to_string())
  }
}

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

///|
pub extend Circuit with Show::{output, to_string}
