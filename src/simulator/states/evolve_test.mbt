///|
test "evolve preserves phase and target order before terminal measurements" {
  let a = @circuit.QuditId::new(0UL, 2U)
  let spectator = @circuit.QuditId::new(1UL, 3U)
  let b = @circuit.QuditId::new(2UL, 2U)
  let circuit = @circuit.Circuit::new([a, spectator, b])
  circuit.extend_ops([
    @circuit.Operation::new(@gates.h(), [b]),
    @circuit.Operation::new(@gates.cnot(), [b, a]),
    @circuit.Operation::new(@gates.s(), [a]),
    @circuit.measure([b, a]),
  ])
  // In wire order [a, spectator, b], the state is (|000> + i|101>) / sqrt(2).
  let state = @states.evolve(circuit.compile())
  assert_eq(state.dim(), [2U, 3U, 2U])
  let amplitudes = state.amplitudes()
  assert_eq(amplitudes.length(), 12)
  let s = 1.0 / 2.0.sqrt()
  for i, amplitude in amplitudes {
    let expected_re = if i == 0 { s } else { 0.0 }
    let expected_im = if i == 7 { s } else { 0.0 }
    // Allow 1.0e-12 error.
    assert_true((amplitude.re - expected_re).abs() < 1.0e-12)
    assert_true((amplitude.im - expected_im).abs() < 1.0e-12)
  }
}
