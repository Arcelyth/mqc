///|
test "when skips or applies a gate using the latest measurement" {
  let control = @circuit.QubitId(0U)
  let target = @circuit.QubitId(1U)
  let flip = @circuit.Operation::new(@gates.x(), [target]).when(
    @circuit.MeasurementCondition::Nonzero("control"),
  )
  let program = @circuit.Circuit::from_op([
    @circuit.measure([control], key="control"),
    flip,
    @circuit.measure([target], key="before"),
    @circuit.Operation::new(@gates.x(), [control]),
    @circuit.measure([control], key="control"),
    flip,
    @circuit.measure([target], key="after"),
  ]).compile()
  let samplers : Array[&@simulator.Sampler] = [
    @simulator.StateVectorSimulator::new(),
    @simulator.DensityMatrixSimulator::new(),
  ]
  for sampler in samplers {
    assert_eq(sampler.run(program).records.to_array(), [0, 0, 1, 1])
  }
}
