///|
test "density evolution matches complex pure-state evolution on nonadjacent reversed targets" {
  let a = @circuit.QuditId::new(0UL, 2U)
  let spectator = @circuit.QuditId::new(1UL, 3U)
  let b = @circuit.QuditId::new(2UL, 2U)
  let circuit = @circuit.Circuit::new([a, spectator, b])
  circuit.extend_ops([
    @circuit.Operation::new(@gates.h(), [b]),
    @circuit.Operation::new(@gates.cnot(), [b, a]),
    @circuit.Operation::new(@gates.s(), [a]),
  ])
  let simulator = @simulator.DensityMatrixSimulator::new(seed=7UL)
  let program = circuit.compile()
  let trial = simulator.simulate(program)
  let matrix = trial.state.density_matrix()
  let pure = @simulator.StateVectorSimulator::new(seed=7UL).simulate(program).state.statevector()
  let expected = @simulator.DensityMatrix::from_state(pure)
  for row in 0..<matrix.size() {
    for column in 0..<matrix.size() {
      let error = matrix.entry(row, column) - expected.entry(row, column)
      assert_true(error.norm_squared() < 1.0e-24)
    }
  }
  assert_true((matrix.entry(0, 7).im + 0.5).abs() < 1.0e-12)
  assert_true((matrix.purity() - 1.0).abs() < 1.0e-12)
  assert_eq(trial.records.shape(), (1, 1, 0))
  // An earlier snapshot must not change when the simulator executes later gates.
  let snapshots : Array[@simulator.DensityMatrix] = []
  ignore(
    simulator.simulate_steps(program, step => {
      snapshots.push(step.state.density_matrix())
    }),
  )
  assert_eq(snapshots.length(), 3)
  assert_true((snapshots[0].entry(0, 1).re - 0.5).abs() < 1.0e-12)
  assert_eq(snapshots[0].entry(0, 7), @maths.Complex::real(0.0))
}

///|
test "density partial measurement preserves unmeasured coherence and supports later gates" {
  let a = @circuit.QubitId(0UL)
  let b = @circuit.QubitId(1UL)
  let circuit = @circuit.Circuit::from_op([
    @circuit.Operation::new(@gates.h(), [a]),
    @circuit.Operation::new(@gates.h(), [b]),
    @circuit.Operation::new(@gates.s(), [b]),
    @circuit.measure([a]),
    @circuit.Operation::new(@gates.x(), [a]),
    @circuit.measure([a]),
  ])
  let simulator = @simulator.DensityMatrixSimulator::new(seed=19UL)
  let same_seed = @simulator.DensityMatrixSimulator::new(seed=19UL)
  let program = circuit.compile()
  let samples = simulator.run(program, repetitions=64)
  assert_eq(samples.records.shape(), (64, 1, 2))
  assert_eq(
    samples.records.to_array(),
    same_seed.run(program, repetitions=64).records.to_array(),
  )
  let mut zeros = 0
  for shot in 0..<64 {
    let first = samples.records.get(shot, 0, 0).unwrap()
    assert_true(first == 0 || first == 1)
    assert_eq(samples.records.get(shot, 0, 1), Some(1 - first))
    if first == 0 {
      zeros += 1
    }
  }
  assert_true(zeros > 0 && zeros < 64)

  let trial = simulator.simulate(program)
  let outcome = trial.records.get(0, 0, 1).unwrap()
  let matrix = trial.state.density_matrix()
  for row in 0..<4 {
    for column in 0..<4 {
      let expected = if row / 2 == outcome && column / 2 == outcome {
        if row == column {
          @maths.Complex::real(0.5)
        } else if row < column {
          @maths.Complex::new(0.0, -0.5)
        } else {
          @maths.Complex::new(0.0, 0.5)
        }
      } else {
        @maths.Complex::real(0.0)
      }
      assert_true(
        (matrix.entry(row, column) - expected).norm_squared() < 1.0e-24,
      )
    }
  }
  assert_eq(simulator.run(program, repetitions=0).records.shape(), (0, 1, 2))
}

///|
test "density simulator evolves mixtures without mutating the initial state" {
  let q = @circuit.QubitId(0UL)
  let mixed = @simulator.DensityMatrix::from_mixture(
    [
      @simulator.StateVector::basis([2U], 0),
      @simulator.StateVector::basis([2U], 1),
    ],
    [0.25, 0.75],
  )
  let initial = @simulator.DensityMatrixState::from_density(mixed, seed=5UL)
  let circuit = @circuit.Circuit::from_op([
    @circuit.Operation::new(@gates.h(), [q]),
  ])
  let simulator = @simulator.DensityMatrixSimulator::new(seed=7UL)
  let result = simulator.simulate(circuit.compile(), initial_state=initial).state.density_matrix()
  assert_true((result.entry(0, 1).re + 0.25).abs() < 1.0e-12)
  assert_true((result.purity() - 0.625).abs() < 1.0e-12)
  assert_eq(initial.density_matrix().probabilities(), [0.25, 0.75])
  let wrong = @simulator.DensityMatrixState::new([3U])
  let mismatch = Ok(simulator.simulate(circuit.compile(), initial_state=wrong)) catch {
    error => Err(error)
  }
  assert_true(mismatch is Err(@error.RegisterMismatch))
}

///|
test "density measurement preserves Bell correlations and requested qudit digit order" {
  let a = @circuit.QuditId::new(0UL, 2U)
  let spectator = @circuit.QuditId::new(1UL, 3U)
  let b = @circuit.QuditId::new(2UL, 2U)
  let circuit = @circuit.Circuit::new([a, spectator, b])
  let shift = @circuit.Gate::monomial("shift", [3U], [2, 0, 1], [
    @maths.Complex::real(1.0),
    @maths.Complex::real(1.0),
    @maths.Complex::real(1.0),
  ])
  circuit.extend_ops([
    @circuit.Operation::new(@gates.h(), [b]),
    @circuit.Operation::new(@gates.cnot(), [b, a]),
    @circuit.Operation::new(shift, [spectator]),
    @circuit.measure([spectator, b]),
    @circuit.measure([a, spectator, b]),
  ])
  let simulator = @simulator.DensityMatrixSimulator::new(seed=11UL)
  let samples = simulator.run(circuit.compile(), repetitions=32)
  assert_eq(samples.records.shape(), (32, 1, 5))

  let mut zeros = 0
  for shot in 0..<32 {
    let bit = samples.records.get(shot, 0, 1).unwrap()
    assert_true(bit == 0 || bit == 1)
    assert_eq(samples.records.get(shot, 0, 0), Some(1))
    assert_eq(samples.records.get(shot, 0, 2), Some(bit))
    assert_eq(samples.records.get(shot, 0, 3), Some(1))
    assert_eq(samples.records.get(shot, 0, 4), Some(bit))
    if bit == 0 {
      zeros += 1
    }
  }
  assert_true(zeros > 0 && zeros < 32)
}

///|
test "amplitude damping transfers one quarter of the excited population to ground" {
  let q = @circuit.QubitId(0UL)
  let program = @circuit.Circuit::from_op([
    @circuit.Operation::new(@gates.x(), [q]),
    @circuit.Operation::new(@circuit.Channel::amplitude_damp(0.25), [q]),
  ]).compile()
  let trial = @simulator.DensityMatrixSimulator::new().simulate(program)
  assert_eq(trial.records.shape(), (1, 1, 0))
  let matrix = trial.state.density_matrix()
  for row in 0..<2 {
    for col in 0..<2 {
      let expected = if row != col {
        0.0
      } else if row == 0 {
        0.25
      } else {
        0.75
      }
      assert_true(
        (matrix.entry(row, col) - @maths.Complex::real(expected)).norm_squared() <
        1.0e-24,
      )
    }
  }
}

///|
test "a local complex channel preserves the spectator and transforms Bell coherence" {
  let a = @circuit.QubitId(0UL)
  let b = @circuit.QubitId(1UL)
  let zero = @maths.Complex::real(0.0)
  let phase = @maths.Complex::new(0.0, 0.75.sqrt())
  let channel = @circuit.Channel::kraus("damp and phase", [2U], [
    [@maths.Complex::real(1.0), zero, zero, phase],
    [zero, @maths.Complex::real(0.5), zero, zero],
  ])
  let program = @circuit.Circuit::from_op([
    @circuit.Operation::new(@gates.h(), [a]),
    @circuit.Operation::new(@gates.cnot(), [a, b]),
    @circuit.Operation::new(channel, [b]),
  ]).compile()
  let matrix = @simulator.DensityMatrixSimulator::new().simulate(program).state.density_matrix()
  for row in 0..<4 {
    for col in 0..<4 {
      let expected = match (row, col) {
        (0, 0) => @maths.Complex::real(0.5)
        (2, 2) => @maths.Complex::real(0.125)
        (3, 3) => @maths.Complex::real(0.375)
        (0, 3) => phase.conjugate().scale(0.5)
        (3, 0) => phase.scale(0.5)
        _ => zero
      }
      assert_true((matrix.entry(row, col) - expected).norm_squared() < 1.0e-24)
    }
  }
}
