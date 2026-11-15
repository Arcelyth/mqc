///|
test "circuit discovers wires and compiles targets in operation order" {
  let a = @circuit.QuditId::new(0UL, 2U)
  let b = @circuit.QuditId::new(1UL, 3U)
  let c = @circuit.QuditId::new(2UL, 2U)
  let circuit = @circuit.Circuit::from_op([
    @circuit.measure([b, a], key="first"),
  ])
  circuit.append(@circuit.measure([c, b], key="second"))
  circuit.extend_ops([@circuit.measure([a], key="third")])
  assert_eq(circuit.qids(), [b, a, c])
  assert_eq(circuit.dimensions(), [3U, 2U, 2U])
  assert_eq(circuit.index_of(a), Some(1))
  assert_eq(circuit.index_of(c), Some(2))

  let keys = []
  for operation in circuit.operations() {
    keys.push(operation.effect().measurement_key())
  }
  assert_eq(keys, [Some("first"), Some("second"), Some("third")])
  let program = circuit.compile()
  assert_eq(program.dimensions(), [3U, 2U, 2U])
  let targets = []
  for instruction in program.instructions() {
    targets.push(instruction.targets())
  }
  assert_eq(targets, [[0, 1], [2, 0], [1]])
}

///|
test "circuit rejects duplicate wire IDs" {
  let q = @circuit.QubitId(0UL)
  let result = Ok(@circuit.Circuit::new([q, q])) catch { error => Err(error) }
  assert_true(result is Err(@circuit.QuantumError::DuplicateQid(1)))
}
