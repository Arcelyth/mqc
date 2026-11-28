///|
test "circuit discovers wires and compiles targets in operation order" {
  let a = @circuit.QuditId::new(0U, 2U)
  let b = @circuit.QuditId::new(1U, 3U)
  let c = @circuit.QuditId::new(2U, 2U)
  let circuit = @circuit.Circuit::from_op([
    @circuit.measure([b, a], key="first"),
  ])
  let copy = circuit.copy()
  circuit.append(@circuit.measure([c, b], key="second"))
  circuit.extend_ops([@circuit.measure([a], key="third")])
  let qids = circuit.qids()
  qids[0] = c
  assert_eq(circuit.qids(), [b, a, c])
  assert_eq(circuit.dim(), [3U, 2U, 2U])
  assert_eq(circuit.index_of(a), Some(1))
  assert_eq(circuit.index_of(c), Some(2))
  assert_eq(copy.qids(), [b, a])
  assert_eq(copy.index_of(c), None)
  assert_eq(copy.length(), 1)

  let keys = []
  for operation in circuit.operations() {
    keys.push(operation.effect().measurement_key())
  }
  assert_eq(keys, [Some("first"), Some("second"), Some("third")])
  let program = circuit.compile()
  assert_eq(program.dim(), [3U, 2U, 2U])
  let targets = []
  for instruction in program.instructions() {
    guard instruction is Operation(op) else {
      fail("expected a quantum operation")
    }
    targets.push(op.targets())
  }
  assert_eq(targets, [[0, 1], [2, 0], [1]])
}

///|
test "circuit rejects duplicate wire IDs" {
  let q = @circuit.QubitId(0U)
  let result = Ok(@circuit.Circuit::new([q, q])) catch { error => Err(error) }
  assert_true(result is Err(@circuit.CircuitError::DuplicateQid(1)))
}

///|
test "concatenation retains idle wires and remapping preserves local target positions" {
  let a = @circuit.QubitId(0U)
  let b = @circuit.QubitId(1U)
  let c = @circuit.QubitId(2U)
  let left = @circuit.Circuit::new([b, a])
  left.append(@circuit.measure([a], key="left"))
  let right = @circuit.Circuit::new([c, b])
  right.append(@circuit.measure([b], key="right"))
  let joined = left.concat(right)
  assert_eq(joined.qids(), [b, a, c])
  assert_eq(left.length(), 1)
  assert_eq(right.length(), 1)

  let mut calls = 0
  let mapped = joined.remap(fn(q) {
    calls += 1
    @circuit.QubitId(q.0 + 10U)
  })
  assert_eq(calls, 3)
  assert_eq(mapped.dim(), [2U, 2U, 2U])
  let targets = []
  for instruction in mapped.compile().instructions() {
    guard instruction is Operation(op) else {
      fail("expected a quantum operation")
    }
    targets.push(op.targets())
  }
  assert_eq(targets, [[1], [0]])
  let duplicate = Ok(joined.remap(fn(_) { a })) catch { error => Err(error) }
  assert_true(duplicate is Err(@circuit.CircuitError::DuplicateQid(_)))

  let measured_adjoint = Ok(joined.adjoint()) catch { error => Err(error) }
  assert_true(measured_adjoint is Err(@circuit.CircuitError::InvalidGate(_)))
  joined.append(@circuit.measure([c], key="later"))
  assert_eq(mapped.length(), 2)
}
