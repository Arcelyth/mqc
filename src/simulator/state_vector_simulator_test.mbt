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

///|
test "gates after repeated measurements use the collapsed state in every shot" {
  let q = @circuit.QubitId(0UL)
  let circuit = @circuit.Circuit::from_op([
    @circuit.Operation::new(@gates.h(), [q]),
    @circuit.measure([q]),
    @circuit.Operation::new(@gates.x(), [q]),
    @circuit.measure([q]),
  ])
  let program = circuit.compile()
  let simulator = @simulator.StateVectorSimulator::new(seed=19UL)
  let same_seed = @simulator.StateVectorSimulator::new(seed=19UL)
  let samples = simulator.run(program, repetitions=64)
  assert_eq(samples.records.shape(), (64, 1, 2))
  assert_eq(
    samples.records.to_array(),
    same_seed.run(program, repetitions=64).records.to_array(),
  )

  let mut zeros = 0
  for shot in 0..<64 {
    let before = samples.records.get(shot, 0, 0).unwrap()
    assert_true(before == 0 || before == 1)
    // The second measurement result must be equal to the inverse value of the first measurement result.
    assert_eq(samples.records.get(shot, 0, 1), Some(1 - before))
    zeros += if before == 0 { 1 } else { 0 }
  }
  assert_true(zeros > 0 && zeros < 64)
  let trial = simulator.simulate(program)
  let last = trial.records.get(0, 0, 1).unwrap()
  assert_eq(trial.records.get(0, 0, 0), Some(1 - last))
  assert_true(
    (trial.state.statevector().amplitude(last).norm_squared() - 1.0).abs() <
    1.0e-12,
  )
  // Since `evolve` is for fast path, it not support measurement.
  let unsupported_fast_path = Ok(@result_data.evolve(program)) catch {
    error => Err(error)
  }
  assert_true(unsupported_fast_path is Err(@error.QError::InvalidState(_)))
  assert_eq(simulator.run(program, repetitions=0).records.shape(), (0, 1, 2))
}
