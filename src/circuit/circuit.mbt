///|
/// Represent a quantum circuit which shares the operation sequence.
struct Circuit[Q] {
  /// Logical wire identifiers in basis order.
  mut wires : Array[Q]
  /// Ordered wire dimensions.
  mut shape : Array[UInt32]
  /// Positions for each local id.
  mut indices : Map[Q, Int32]
  /// Instruction sequence in execution order.
  mut ops : @vector.Vector[Operation[Q]]
  /// The union of names from every effect in current circuit.
  mut parameter_names : @hashset.HashSet[String]
}

///|
/// Create an empty circuit over an ordered list of distinct logical IDs.
pub fn[Q : Qid] Circuit::new(qids : Array[Q]) -> Circuit[Q] raise QuantumError {
  let indices : Map[Q, Int32] = Map([])
  let shape : Array[UInt32] = []
  for i, q in qids {
    if indices.contains(q) {
      raise DuplicateQid(i)
    }
    let dim = q.dimension()
    if dim < 2U {
      raise InvalidDimension(dim)
    }
    indices[q] = i
    shape.push(dim)
  }
  {
    wires: qids.copy(),
    shape,
    indices,
    ops: @vector.Vector::new(),
    parameter_names: @hashset.HashSet::new(),
  }
}

///|
/// Build a circuit from bound operations in execution order.
pub fn[Q : Qid] Circuit::from_op(
  operations : Array[Operation[Q]],
) -> Circuit[Q] raise QuantumError {
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
) -> Unit raise QuantumError {
  self.extend_ops([operation])
}

///|
/// Append a list of operations in place, in the supplied order.
pub fn[Q : Qid] Circuit::extend_ops(
  self : Circuit[Q],
  operations : Array[Operation[Q]],
) -> Unit raise QuantumError {
  let mut wires = self.wires
  let mut shape = self.shape
  let mut indices = self.indices
  let mut copied_wires = false
  let mut ops = self.ops
  let mut parameter_names = self.parameter_names
  for operation in operations {
    for i, qid in operation.wires {
      let dimension = qid.dimension()
      match indices.get(qid) {
        Some(index) =>
          if dimension != shape[index] {
            raise DimensionMismatch(i, shape[index], dimension)
          }
        None => {
          if dimension < 2U {
            raise InvalidDimension(dimension)
          }
          // Copy when first new Qid appears.
          if !copied_wires {
            wires = wires.copy()
            shape = shape.copy()
            indices = indices.copy()
            copied_wires = true
          }
          indices[qid] = wires.length()
          wires.push(qid)
          shape.push(dimension)
        }
      }
    }
    ops = ops.push(operation)
    parameter_names = add_names(parameter_names, operation.effect.parameters())
  }
  self.wires = wires
  self.shape = shape
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
pub fn[Q] Circuit::dimensions(self : Circuit[Q]) -> Array[UInt32] {
  self.shape.copy()
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
  { label: name, shape: self.shape.copy(), ops, }
}
