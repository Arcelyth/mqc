///|
/// Represent a quantum circuit which shares the operation sequence.
struct Circuit[Q] {
  /// Logical wire identifiers in basis order.
  wires : Array[Q]
  /// Ordered wire dimensions.
  shape : Array[UInt32]
  /// Positions for each local id.
  indices : Map[Q, Int32]
  /// Instruction sequence in execution order.
  ops : @vector.Vector[Operation[Q]]
  /// The union of names from every effect in current circuit.
  parameter_names : @hashset.HashSet[String]
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
