///|
test "state-vector simulator samples Bell correlations and returns a collapsed trial" {
  let a = @circuit.QubitId(0UL)
  let b = @circuit.QubitId(1UL)
  let circuit = @circuit.Circuit::from_op([
    @circuit.Operation::new(@gates.h(), [a]),
    @circuit.Operation::new(@gates.cnot(), [a, b]),
    @circuit.measure([a, b]),
  ])
  let program = circuit.compile()
  let simulator = @simulator.StateVectorSimulator::new(seed=67UL)
  let same_seed = @simulator.StateVectorSimulator::new(seed=67UL)
  let samples = simulator.run(program, repetitions=100)
  assert_eq(samples.records.shape(), (100, 1, 2))
  // Check whether the random generator produces the same result for the same seed.
  assert_eq(
    samples.records.to_array(),
    same_seed.run(program, repetitions=100).records.to_array(),
  )

  let mut zeros = 0
  for shot in 0..<100 {
    let first = samples.records.get(shot, 0, 0).unwrap()
    assert_true(first == 0 || first == 1)
    assert_eq(samples.records.get(shot, 0, 1), Some(first))
    if first == 0 {
      zeros += 1
    }
  }
  assert_true(zeros > 0 && zeros < 100)

  let trial = simulator.simulate(program)
  assert_eq(trial.records.shape(), (1, 1, 2))
  assert_eq(
    trial.records.to_array(),
    same_seed.simulate(program).records.to_array(),
  )
  // Check the collapse: both need to be the same according to bell state.
  let outcome = trial.records.get(0, 0, 0).unwrap()
  assert_true(outcome == 0 || outcome == 1)
  assert_eq(trial.records.get(0, 0, 1), Some(outcome))

  let amplitudes = trial.state.statevector().amplitudes()
  assert_eq(amplitudes.length(), 4)
  for i, amplitude in amplitudes {
    let expected = if i == outcome * 3 { 1.0 } else { 0.0 }
    assert_true((amplitude.re - expected).abs() < 1.0e-12)
    assert_true(amplitude.im.abs() < 1.0e-12)
  }
}
