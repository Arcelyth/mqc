///|
test "a fixed I/X mixture evolves populations and samples one gate per shot" {
  let q = @circuit.QubitId(0U)
  let channel = @circuit.Channel::mixture([
    (0.75, @gates.i()),
    (0.25, @gates.x()),
  ])
  let circuit = @circuit.Circuit::from_op([
    @circuit.Operation::new(channel, [q]),
  ])
  let density = @simulator.DensityMatrixSimulator::new().simulate(
    circuit.compile(),
  )
  let matrix = density.state.density_matrix()
  assert_true((matrix.entry(0, 0).re - 0.75).abs() < 1.0e-12)
  assert_true((matrix.entry(1, 1).re - 0.25).abs() < 1.0e-12)
  assert_eq(matrix.entry(0, 1), @maths.Complex::real(0.0))
  circuit.append(@circuit.measure([q]))
  let records = @simulator.StateVectorSimulator::new(seed=53UL).run(
      circuit.compile(),
      repetitions=1024,
    ).records
  assert_eq(records.shape(), (1024, 1, 1))
  let mut flips = 0
  for bit in records.to_array() {
    flips += bit
  }
  assert_true((flips - 256).abs() < 64)
}
