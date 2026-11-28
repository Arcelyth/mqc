///|
/// A quantum circuit and its ordered instruction sequence.
struct Circuit[Q] {
  /// Logical wire identifiers in basis order.
  mut qubits : Registry[Q]
  /// Classical identifiers in registration order.
  mut clbits : Registry[Clbit]
  /// Instruction sequence in execution order.
  ops : Array[Instruction[Q]]
  /// Symbols used by instructions and the global phase.
  mut param : @parameter.ParameterTable
  mut global_phase : ParamExpr
}

///|
/// Create an empty circuit over an ordered list of distinct logical IDs.
pub fn[Q : Qid] Circuit::new(
  qids : Array[Q],
  clbits~ : Array[Clbit] = [],
) -> Circuit[Q] raise CircuitError {
  {
    qubits: Registry::new(qids),
    clbits: Registry::new(clbits),
    ops: [],
    param: @parameter.ParameterTable::empty(),
    global_phase: ParamExpr::constant(0.0),
  }
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
pub fn[Q] Circuit::copy(self : Circuit[Q]) -> Circuit[Q] {
  { ..self, ops: self.ops.copy(), }
}

///|
/// Append an operation.
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
  let qubits = self.qubits.with_targets(operations.iter().map(op => op.wires))
  let mut param = self.param
  let offset = self.ops.length()
  for position, operation in operations {
    param = param.track(operation.effect.parameter_symbols(), offset + position) catch {
      error => raise CircuitError::Parameter(error)
    }
  }
  self.qubits = qubits
  self.param = param
  for operation in operations {
    self.ops.push(Operation(operation))
  }
}

///|
pub fn[Q] Circuit::qids(self : Circuit[Q]) -> Array[Q] {
  self.qubits.items.copy()
}

///|
pub fn[Q] Circuit::clbits(self : Circuit[Q]) -> Array[Clbit] {
  self.clbits.items.copy()
}

///|
/// Register a new classical bit at the end of the classical registry.
pub fn[Q] Circuit::add_clbit(
  self : Circuit[Q],
  bit : Clbit,
) -> Unit raise CircuitError {
  self.clbits = self.clbits.add(bit)
}

///|
/// Look up a classical bit's index in the classical registry.
pub fn[Q] Circuit::clbit_index(self : Circuit[Q], bit : Clbit) -> Int32? {
  self.clbits.get(bit)
}

///|
/// Return wire dimensions in basis order.
pub fn[Q : Qid] Circuit::dim(self : Circuit[Q]) -> Array[UInt32] {
  self.qubits.dims()
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
/// Iterate over the full sequence.
pub fn[Q] Circuit::instructions(self : Circuit[Q]) -> Iter[Instruction[Q]] {
  let ops = self.ops
  Int32::until(0, ops.length()).map(index => ops[index])
}

///|
/// Count top-level instructions.
pub fn[Q] Circuit::length(self : Circuit[Q]) -> Int32 {
  self.ops.length()
}

///|
/// Find a logical ID's position. Return `None` if absent.
pub fn[Q : Qid] Circuit::index_of(self : Circuit[Q], qid : Q) -> Int32? {
  self.qubits.get(qid)
}

///|
/// Compile the circuit and its global phase to a program.
pub fn[Q : Qid] Circuit::compile(
  self : Circuit[Q],
  name~ : String = "circuit",
) -> Program {
  let qubits = self.qubits
  {
    label: name,
    shape: @internal.Shape::new(qubits.dims()),
    ops: self
    .execution_instructions()
    .map(instruction => instruction.map_wires(q => qubits.index(q)))
    .collect(),
  }
}

///|
/// Return a new circuit executing self followed by other.
/// Append new quantum and classical wires in order. Add the global phases.
pub fn[Q : Qid] Circuit::concat(
  self : Circuit[Q],
  other : Circuit[Q],
) -> Circuit[Q] raise CircuitError {
  let qubits = self.qubits.merge(other.qubits)
  let (param, global_phase) = try {
    let param = self.param.concat(other.param, self.length())
    let phase = if self.global_phase.constant_value() == Some(0.0) {
      other.global_phase
    } else if other.global_phase.constant_value() == Some(0.0) {
      self.global_phase
    } else {
      (self.global_phase + other.global_phase).assign(Map([]))
    }
    (param, phase)
  } catch {
    error => raise CircuitError::Parameter(error)
  }
  {
    qubits,
    clbits: self.clbits.union(other.clbits),
    ops: self.ops + other.ops,
    param,
    global_phase,
  }
}

///|
/// Map each logical wire once, preserving wire and target order.
pub fn[Q : Qid, R : Qid] Circuit::remap(
  self : Circuit[Q],
  map : (Q) -> R,
) -> Circuit[R] raise CircuitError {
  let registry = self.qubits
  let ops = self.instructions()
  let wires = registry.items.map(map)
  for i, qid in wires {
    let dim = qid.dim()
    let expected = registry.dim_at(i)
    if dim != expected {
      raise DimensionMismatch(i, expected, dim)
    }
  }
  {
    qubits: Registry::new(wires),
    clbits: self.clbits,
    ops: ops
    .map(instruction => instruction.map_wires(q => wires[registry.index(q)]))
    .collect(),
    param: self.param,
    global_phase: self.global_phase,
  }
}

///|
/// Reverse the operation order and replace each effect with its adjoint.
/// Reject effects without an adjoint.
pub fn[Q : Qid] Circuit::adjoint(
  self : Circuit[Q],
) -> Circuit[Q] raise CircuitError {
  let result = adjoint_body(self.qubits.items, self.ops)
  result.clbits = self.clbits
  result.set_global_phase(-self.global_phase) catch {
    error => raise CircuitError::Parameter(error)
  }
  result
}

///|
/// Count the measurement columns reserved by a loop.
fn[Q] Circuit::loop_width(
  self : Circuit[Q],
  count : Int32,
) -> Int32 raise CircuitError {
  guard count > 0 else { return 0 }
  let width = self.record_width()
  if width > 2147483647 / count {
    raise SizeLimit(2147483647)
  }
  width * count
}

///|
/// Return a circuit with the model's noise inserted after each unitary gate.
/// The model visits each original gate once, including gates inside branches
/// and loop bodies. A guarded gate and its noise share one branch decision.
pub fn[Q : Qid] Circuit::with_noise(
  self : Circuit[Q],
  model : &NoiseModel,
) -> Circuit[Q] raise CircuitError {
  let result = self.noisy_body(self.instructions(), self.qubits.items, model)
  result.clbits = self.clbits
  result.set_global_phase(self.global_phase) catch {
    error => raise CircuitError::Parameter(error)
  }
  result
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
  let registry = self.qubits
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
  let wires = self.qubits
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
pub extend Circuit with Show::{output, to_string}

///|
fn[Q] Circuit::execution_instructions(
  self : Circuit[Q],
) -> Iter[Instruction[Q]] {
  let ops = self.instructions()
  match GlobalPhase::instruction(self.global_phase) {
    Some(phase) => Iter::singleton(phase).concat(ops)
    None => ops
  }
}

///|
/// Append a branch. Evaluate the condition once and execute the selected body.
pub fn[Q : Qid] Circuit::if_else(
  self : Circuit[Q],
  condition : &Condition,
  on_true : Circuit[Q],
  on_false : Circuit[Q],
) -> Unit raise CircuitError {
  let qubits = on_true.qubits.merge(on_false.qubits)
  let clbits = on_true.clbits.union(on_false.clbits)
  let true_ops = on_true.execution_instructions().collect()
  let false_ops = on_false.execution_instructions().collect()
  let branch = IfElse::{
    condition,
    on_true: true_ops,
    on_false: false_ops,
    names: instruction_parameter_names(true_ops.iter().concat(false_ops.iter())),
    width: on_true.record_width().max(on_false.record_width()),
  }
  self.append_block(qubits, clbits, IfElse(branch))
}

///|
fn[Q] Circuit::record_width(self : Circuit[Q]) -> Int32 raise CircuitError {
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
/// Append a loop that executes the body exactly count times on the same state.
/// Each measurement appends its digits in iteration order. A count of zero
/// skips the body. A negative count raises InvalidState.
pub fn[Q : Qid] Circuit::for_loop(
  self : Circuit[Q],
  count : Int32,
  body : Circuit[Q],
) -> Unit raise CircuitError {
  if count < 0 {
    raise InvalidState("loop count must be nonnegative")
  }
  let ops = body.execution_instructions().collect()
  let names = if count > 0 {
    instruction_parameter_names(ops.iter())
  } else {
    []
  }
  let width = body.loop_width(count)
  self.append_block(
    body.qubits,
    body.clbits,
    ForLoop({ count, body: ops, names, width, }),
  )
}

///|
/// Test the condition before each iteration. Body measurements are available
/// to the next test. If the condition still holds after max_iterations,
/// execution raises IterationLimit. Unused record columns contain -1.
pub fn[Q : Qid] Circuit::while_loop(
  self : Circuit[Q],
  condition : &Condition,
  body : Circuit[Q],
  max_iterations~ : Int32,
) -> Unit raise CircuitError {
  if max_iterations < 0 {
    raise InvalidState("max_iterations must be nonnegative")
  }
  let ops = body.execution_instructions().collect()
  let names = if max_iterations > 0 {
    instruction_parameter_names(ops.iter())
  } else {
    []
  }
  let width = body.loop_width(max_iterations)
  self.append_block(
    body.qubits,
    body.clbits,
    WhileLoop({ condition, max_iterations, body: ops, names, width, }),
  )
}

///|
fn[Q : Qid] Circuit::append_block(
  self : Circuit[Q],
  body_qubits : Registry[Q],
  body_clbits : Registry[Clbit],
  instruction : Instruction[Q],
) -> Unit raise CircuitError {
  let qubits = self.qubits.merge(body_qubits)
  let param = self.param.track(instruction.parameter_symbols(), self.length()) catch {
    error => raise CircuitError::Parameter(error)
  }
  self.qubits = qubits
  self.clbits = self.clbits.union(body_clbits)
  self.param = param
  self.ops.push(instruction)
}

///|
pub fn[Q] Circuit::parameters(self : Circuit[Q]) -> Array[Parameter] {
  self.param.parameters()
}

///|
/// Find a free parameter by name.
pub fn[Q] Circuit::get_parameter(
  self : Circuit[Q],
  name : String,
) -> Parameter? {
  self.param.get_by_name(name)
}

///|
pub fn[Q] Circuit::global_phase(self : Circuit[Q]) -> ParamExpr {
  self.global_phase
}

///|
pub fn[Q] Circuit::set_global_phase(
  self : Circuit[Q],
  phase : ParamExpr,
) -> Unit raise ParameterError {
  let phase = phase.assign(Map([]))
  let param = self.param.untrack_phase(self.global_phase.parameters())
  self.param = param.track_phase(phase.parameters())
  self.global_phase = phase
}

///|
/// Assign real values to a subset of the circuit's free parameters.
pub fn[Q] Circuit::bind(
  self : Circuit[Q],
  values : Map[Parameter, Double],
  strict~ : Bool = true,
) -> Unit raise {
  self.assign_parameters(
    values.map((_, value) => ParamExpr::constant(value)),
    strict~,
  )
}

///|
/// Substitute the supplied expressions simultaneously in the indexed uses.
/// In `strict` mode, each supplied parameter must occur in the circuit.
pub fn[Q] Circuit::assign_parameters(
  self : Circuit[Q],
  bindings : Map[Parameter, ParamExpr],
  strict~ : Bool = true,
) -> Unit raise {
  let positions = self.param.positions(bindings.keys(), strict)
  let phase_params = self.global_phase.parameters()
  let change_phase = phase_params.iter().any(p => bindings.contains(p))
  let mut param = self.param
  let phase = if change_phase {
    param = param.untrack_phase(phase_params)
    self.global_phase.assign(bindings)
  } else {
    self.global_phase
  }
  let replacements = positions.map(position => {
    let old = self.ops[position]
    let updated = old.assign_parameters(bindings)
    param = param.untrack(old.parameter_symbols(), position)
    updated
  })
  for i, position in positions {
    param = param.track(replacements[i].parameter_symbols(), position)
  }
  if change_phase {
    param = param.track_phase(phase.parameters())
  }
  for i, position in positions {
    self.ops[position] = replacements[i]
  }
  self.global_phase = phase
  self.param = param
}
