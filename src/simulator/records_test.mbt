///|
test "for_key groups repeated measurements under their key in each run" {
  let a = @circuit.QubitId(0UL)
  let b = @circuit.QubitId(1UL)
  let circuit = @circuit.Circuit::from_op([
    @circuit.Operation::new(@gates.x(), [a]),
    @circuit.measure([a, b], key="pair"),
    @circuit.measure([b], key="flag"),
    @circuit.measure([b, a], key="pair"),
  ])
  let simulator = @simulator.StateVectorSimulator::new()
  let records = simulator.run(circuit.compile(), repetitions=2).records
  assert_eq(records.for_key("pair"), [[[1, 0], [0, 1]], [[1, 0], [0, 1]]])
  assert_eq(records.for_key("flag"), [[[0]], [[0]]])
}
