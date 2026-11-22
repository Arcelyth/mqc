///|
test "if_else selects once per block and records only the selected arm" {
  let q = @circuit.QubitId(0UL)
  let flip = @circuit.Operation::new(@gates.x(), [q])
  let measure = @circuit.measure([q], key="m")
  let condition = @circuit.MeasurementCondition::Nonzero("m")
  let on_false = @circuit.Circuit::from_op([flip])
  let on_true = @circuit.Circuit::from_op([flip, measure, flip])
  let circuit = @circuit.Circuit::from_op([measure])
  circuit.if_else(condition, on_true, on_false)
  circuit.append(measure)
  circuit.if_else(condition, on_true, on_false)
  circuit.append(measure)

  let program = circuit.compile()
  let samplers : Array[&@simulator.Sampler] = [
    @simulator.StateVectorSimulator::new(),
    @simulator.DensityMatrixSimulator::new(),
  ]
  for sampler in samplers {
    // The false arm leaves an empty column. The true arm records zero,
    // then finishes its final flip even though the condition has changed.
    assert_eq(sampler.run(program).records.to_array(), [0, -1, 1, 0, 1])
  }
}

///|
test "for_loop carries the state and records measurements across iterations" {
  let q = @circuit.QubitId(0UL)
  let body = @circuit.Circuit::from_op([
    @circuit.Operation::new(@gates.x(), [q]),
    @circuit.measure([q]),
  ])
  let circuit = @circuit.Circuit::new([q])
  circuit.for_loop(0, body)
  circuit.for_loop(3, body)
  let program = circuit.compile()
  let samplers : Array[&@simulator.Sampler] = [
    @simulator.StateVectorSimulator::new(),
    @simulator.DensityMatrixSimulator::new(),
  ]
  for sampler in samplers {
    assert_eq(sampler.run(program).records.to_array(), [1, 0, 1])
  }
}

///|
test "while_loop retests the measurement and pads unused iterations" {
  let q = @circuit.QubitId(0UL)
  let flip = @circuit.Operation::new(@gates.x(), [q])
  let measure = @circuit.measure([q], key="m")
  let condition = @circuit.MeasurementCondition::Nonzero("m")
  let body = @circuit.Circuit::from_op([flip, measure])
  let circuit = body.copy()
  circuit.while_loop(condition, body, max_iterations=2)
  circuit.while_loop(condition, body, max_iterations=1)
  circuit.append(measure)
  let program = circuit.compile()
  let samplers : Array[&@simulator.Sampler] = [
    @simulator.StateVectorSimulator::new(),
    @simulator.DensityMatrixSimulator::new(),
  ]
  for sampler in samplers {
    assert_eq(sampler.run(program).records.to_array(), [1, 0, -1, -1, 0])
  }
}

///|
test "while_loop reports a condition still true at the bound" {
  let q = @circuit.QubitId(0UL)
  let measure = @circuit.measure([q], key="m")
  let circuit = @circuit.Circuit::from_op([
    @circuit.Operation::new(@gates.x(), [q]),
    measure,
  ])
  circuit.while_loop(
    @circuit.MeasurementCondition::Nonzero("m"),
    @circuit.Circuit::from_op([measure]),
    max_iterations=1,
  )
  let samplers : Array[&@simulator.Sampler] = [
    @simulator.StateVectorSimulator::new(),
    @simulator.DensityMatrixSimulator::new(),
  ]
  for sampler in samplers {
    let result = Ok(sampler.run(circuit.compile())) catch { err => Err(err) }
    assert_true(result is Err(@error.IterationLimit(1)))
  }
}
