///|
/// Represent a quantum circuit which shares the operation sequence.
struct Circuit[Q] {
  /// Logical wire identifiers in basis order.
  mut wires : Array[Q]
  /// Ordered wire dimensions.
  mut shape : @internal.Shape
  /// Positions for each local id.
  mut indices : Map[Q, Int32]
  /// Instruction sequence in execution order.
  mut ops : @vector.Vector[Operation[Q]]
  /// The union of names from every effect in current circuit.
  mut parameter_names : @hashset.HashSet[String]
}

///|
/// Create an empty circuit over an ordered list of distinct logical IDs.
pub fn[Q : Qid] Circuit::new(qids : Array[Q]) -> Circuit[Q] raise @error.QError {
  let indices : Map[Q, Int32] = Map([])
  let shape : Array[UInt32] = []
  for i, q in qids {
    if indices.contains(q) {
      raise DuplicateQid(i)
    }
    let dim = q.dim()
    if dim < 2U {
      raise InvalidDimension(dim)
    }
    indices[q] = i
    shape.push(dim)
  }
  {
    wires: qids.copy(),
    shape: @internal.Shape::new(shape),
    indices,
    ops: @vector.Vector::new(),
    parameter_names: @hashset.HashSet::new(),
  }
}

///|
/// Build a circuit from bound operations in execution order.
pub fn[Q : Qid] Circuit::from_op(
  operations : Array[Operation[Q]],
) -> Circuit[Q] raise @error.QError {
  let circuit = Circuit::new([])
  circuit.extend_ops(operations)
  circuit
}

///|
/// Copy this circuit.
pub fn[Q] Circuit::copy(self : Circuit[Q]) -> Circuit[Q] {
  {
    wires: self.wires,
    shape: self.shape,
    indices: self.indices,
    ops: self.ops,
    parameter_names: self.parameter_names,
  }
}

///|
/// Append an operation in place.
pub fn[Q : Qid] Circuit::append(
  self : Circuit[Q],
  operation : Operation[Q],
) -> Unit raise @error.QError {
  self.extend_ops([operation])
}

///|
/// Append a list of operations in place, in the supplied order.
pub fn[Q : Qid] Circuit::extend_ops(
  self : Circuit[Q],
  operations : Array[Operation[Q]],
) -> Unit raise @error.QError {
  let mut wires = self.wires
  let shape = self.shape.to_array()
  let mut indices = self.indices
  let mut copied_wires = false
  let mut ops = self.ops
  let mut parameter_names = self.parameter_names
  for operation in operations {
    for i, qid in operation.wires {
      let dim = qid.dim()
      match indices.get(qid) {
        Some(index) =>
          if dim != shape[index] {
            raise DimensionMismatch(i, shape[index], dim)
          }
        None => {
          if dim < 2U {
            raise InvalidDimension(dim)
          }
          // Copy when first new Qid appears.
          if !copied_wires {
            wires = wires.copy()
            indices = indices.copy()
            copied_wires = true
          }
          indices[qid] = wires.length()
          wires.push(qid)
          shape.push(dim)
        }
      }
    }
    ops = ops.push(operation)
    parameter_names = add_names(parameter_names, operation.effect.parameters())
  }
  self.wires = wires
  self.shape = @internal.Shape::new(shape)
  self.indices = indices
  self.ops = ops
  self.parameter_names = parameter_names
}

///|
/// Return a copy of the logical IDs in order.
pub fn[Q] Circuit::qids(self : Circuit[Q]) -> Array[Q] {
  self.wires.copy()
}

///|
/// Return a copy of the ordered wire dimensions.
pub fn[Q] Circuit::dim(self : Circuit[Q]) -> Array[UInt32] {
  self.shape.to_array()
}

///|
/// Iterate over immutable operations in execution order.
pub fn[Q] Circuit::operations(self : Circuit[Q]) -> Iter[Operation[Q]] {
  self.ops.iter()
}

///|
/// Return the stored operation count, counting a nested effect as one operation.
pub fn[Q] Circuit::length(self : Circuit[Q]) -> Int32 {
  self.ops.length()
}

///|
/// Find a logical ID's position. Return `None` if absent.
pub fn[Q : Qid] Circuit::index_of(self : Circuit[Q], qid : Q) -> Int32? {
  self.indices.get(qid)
}

///|
/// Compile circuit to program.
pub fn[Q : Qid] Circuit::compile(
  self : Circuit[Q],
  name~ : String = "circuit",
) -> Program {
  let mut ops = @vector.Vector::new()
  for operation in self.ops {
    let wires = operation.wires.map(fn(q) { self.indices[q] })
    ops = ops.push(Instruction::{ effect_value: operation.effect, wires, })
  }
  { label: name, shape: self.shape, ops, }
}

///|
/// Return a new circuit executing self followed by other.
/// Append new wires in order.
pub fn[Q : Qid] Circuit::concat(
  self : Circuit[Q],
  other : Circuit[Q],
) -> Circuit[Q] raise @error.QError {
  let wires = self.wires.copy()
  let shape = self.shape.to_array()
  let indices = self.indices.copy()
  for i, qid in other.wires {
    match indices.get(qid) {
      Some(index) =>
        if shape[index] != other.shape[i] {
          raise DimensionMismatch(i, shape[index], other.shape[i])
        }
      None => {
        indices[qid] = wires.length()
        wires.push(qid)
        shape.push(other.shape[i])
      }
    }
  }
  let mut parameter_names = self.parameter_names
  for name in other.parameter_names.iter() {
    parameter_names = parameter_names.add(name)
  }
  {
    wires,
    shape: @internal.Shape::new(shape),
    indices,
    ops: self.ops.concat(other.ops),
    parameter_names,
  }
}

///|
/// Map each logical wire once, preserving wire and target order.
pub fn[Q : Qid, R : Qid] Circuit::remap(
  self : Circuit[Q],
  map : (Q) -> R,
) -> Circuit[R] raise @error.QError {
  let wires = self.wires.map(map)
  for i, qid in wires {
    let dim = qid.dim()
    if dim != self.shape[i] {
      raise DimensionMismatch(i, self.shape[i], dim)
    }
  }
  let result = Circuit::new(wires)
  for operation in self.ops {
    let targets = operation.wires.map(fn(qid) { wires[self.indices[qid]] })
    result.append(Operation::new(operation.effect, targets))
  }
  result
}

///|
/// Reverse operation order and replace each effect with its adjoint:
/// (U₁ U₂ ... Uₙ)† = Uₙ† ... U₂† U₁†.
/// Reject effects without an adjoint.
pub fn[Q : Qid] Circuit::adjoint(
  self : Circuit[Q],
) -> Circuit[Q] raise @error.QError {
  let result = Circuit::new(self.wires)
  for i = self.ops.length() - 1; i >= 0; i = i - 1 {
    let operation = self.ops[i]
    guard operation.effect.try_adjoint() is Some(inverse) else {
      raise InvalidGate("effect has no adjoint: " + operation.effect.name())
    }
    result.append(Operation::new(inverse, operation.wires))
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
  let labels = self.wires.map(wire => Show::to_string(wire))
  let label_width = labels.fold(init=0, (width, label) => {
    width.max(label.length())
  })
  let rows = labels.map(label => {
    let row = StringBuilder()
    row.write_string(label.pad_start(label_width, ' '))
    row.write_string(": ───")
    row
  })
  for operation in self.ops {
    operation.draw_column(rows, self.indices)
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
  indices : Map[Q, Int32],
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
    symbols[indices[wire]] = symbol
    width = width.max(symbol.length())
  }
  for wire, row in rows {
    row.write_string(symbols.get_or_default(wire, "").pad_end(width + 3, '─'))
  }
}

///|
pub extend Circuit with Show::{output, to_string}
