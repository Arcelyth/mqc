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
test "a classical bit can be registered by its identity" {
  let bit = @circuit.Clbit(7U)
  let other = @circuit.Clbit(2U)
  let registry = @circuit.Registry::new([bit])
  let extended = registry.add(other)
  assert_eq(bit.id(), 7U)
  assert_eq(extended.get(bit), Some(0))
  assert_eq(extended.get(other), Some(1))
  assert_eq(registry.get(other), None)
}

///|
test "appending preserves captured loop bodies and existing iterators" {
  let q = @circuit.QubitId(0U)
  let measurement = @circuit.measure([q])
  let body = @circuit.Circuit::from_op([measurement])
  let instructions = body.instructions()
  let circuit = @circuit.Circuit::new([])
  circuit.for_loop(2, body)
  body.append(measurement)
  assert_eq(instructions.collect().length(), 1)
  assert_eq(
    circuit.compile().instructions(expand_loops=true).collect().length(),
    2,
  )
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

///|
test "circuit tracks global phase and captured instructions across concat and binding" {
  let q = @circuit.QubitId(0U)
  let a = @circuit.Clbit(0U)
  let b = @circuit.Clbit(1U)
  let theta = @circuit.Parameter::new("theta")
  let first = @circuit.Circuit::new([q], clbits=[a])
  first.set_global_phase(theta.expr())
  first.for_loop(0, @circuit.Circuit::new([]))
  let body = @circuit.Circuit::new([q], clbits=[b])
  body.set_global_phase(theta.expr() + @circuit.ParamExpr::constant(0.25))
  let second = @circuit.Circuit::new([q], clbits=[a])
  second.for_loop(2, body)
  let circuit = first.concat(second)
  let original = circuit.copy()
  assert_eq(circuit.clbits(), [a, b])
  assert_eq(circuit.clbit_index(b), Some(1))
  assert_eq(circuit.get_parameter("theta"), Some(theta))

  let same_name = @circuit.Parameter::new("theta")
  let result = Ok(circuit.set_global_phase(same_name.expr())) catch {
    error => Err(error)
  }
  assert_true(result is Err(@circuit.ParameterError::NameConflict("theta")))
  assert_eq(circuit.parameters(), [theta])

  circuit.bind(Map([(theta, 0.5)]))
  assert_eq(circuit.global_phase().value(), 0.5)
  assert_eq(circuit.parameters(), [])
  assert_eq(original.parameters(), [theta])
  let instructions = circuit.compile().instructions(expand_loops=true).collect()
  assert_eq(instructions.length(), 3)
  let angles = [0.5, 0.75, 0.75]
  for i, instruction in instructions {
    guard instruction is Operation(op) && op.gate() is Some(gate) else {
      fail("expected a bound phase operation")
    }
    assert_eq(op.targets(), [])
    assert_amplitudes(
      apply_kernel(gate.kernel(), [@maths.Complex::real(1.0)]),
      [@maths.Complex::phase(angles[i])],
    )
  }
}
