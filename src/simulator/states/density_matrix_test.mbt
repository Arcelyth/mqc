///|
fn assert_density_close(actual : Double, expected : Double) -> Unit raise {
  // Allow small rounding differences from normalization and complex arithmetic.
  assert_true((actual - expected).abs() < 1.0e-12)
}

///|
test "pure density matrices preserve complex coherence and Hermitian symmetry" {
  // The pure state is |psi> = (|0> + i|1>) / sqrt(2).
  // Its outer product gives:
  //   rho = [ 0.5  -0.5i ]
  //         [ 0.5i   0.5 ]
  // Entries are returned in row-major order.
  let r = 1.0 / 2.0.sqrt()
  let state = @states.StateVector::from_amplitudes([2U], [
    @maths.Complex::real(r),
    @maths.Complex::new(0.0, r),
  ])
  let matrix = @states.DensityMatrix::from_state(state)
  let expected = [
    @maths.Complex::real(0.5),
    @maths.Complex::new(0.0, -0.5),
    @maths.Complex::new(0.0, 0.5),
    @maths.Complex::real(0.5),
  ]
  for i, entry in matrix.entries() {
    assert_density_close(entry.re, expected[i].re)
    assert_density_close(entry.im, expected[i].im)
  }
  // Hermitian symmetry requires rho[1, 0] = conjugate(rho[0, 1]).
  assert_eq(matrix.entry(1, 0), matrix.entry(0, 1).conjugate())
  // The diagonal sums to one, and a pure state has trace(rho^2) = 1.
  assert_density_close(matrix.trace(), 1.0)
  assert_density_close(matrix.purity(), 1.0)
  // Measuring either basis state has probability 0.5.
  for probability in matrix.probabilities() {
    assert_density_close(probability, 0.5)
  }
}

///|
test "nonorthogonal pure states produce a mixed density matrix" {
  // Mix |0> with weight 0.25 and |plus_i> = (|0> + i|1>) / sqrt(2)
  // with weight 0.75. Their overlap is nonzero, so these states are not orthogonal.
  //   rho = 0.25 * |0><0| + 0.75 * |plus_i><plus_i|
  //       = [ 0.625  -0.375i ]
  //         [ 0.375i   0.375 ]
  let r = 1.0 / 2.0.sqrt()
  let plus_i = @states.StateVector::from_amplitudes([2U], [
    @maths.Complex::real(r),
    @maths.Complex::new(0.0, r),
  ])
  let matrix = @states.DensityMatrix::from_mixture(
    [@states.StateVector::basis([2U], 0), plus_i],
    [0.25, 0.75],
  )
  assert_density_close(matrix.entry(0, 0).re, 0.625)
  assert_density_close(matrix.entry(1, 1).re, 0.375)
  assert_density_close(matrix.entry(0, 1).re, 0.0)
  assert_density_close(matrix.entry(0, 1).im, -0.375)
  assert_eq(matrix.entry(1, 0), matrix.entry(0, 1).conjugate())
  assert_density_close(matrix.trace(), 1.0)
  // Purity = 0.625^2 + 0.375^2 + 2 * 0.375^2 = 0.8125, below one.
  assert_density_close(matrix.purity(), 0.8125)
}

///|
test "density marginals sum unmeasured wires and respect target order" {
  // Mix three basis states of a qubit and a qutrit. All off-diagonal entries are zero.
  //   basis:        |00> |01> |02> |10> |11> |12>
  //   probability:  0.25  0.00  0.25  0.00  0.50  0.00
  let matrix = @states.DensityMatrix::from_mixture(
    [
      @states.StateVector::basis([2U, 3U], 0),
      @states.StateVector::basis([2U, 3U], 2),
      @states.StateVector::basis([2U, 3U], 4),
    ],
    [0.25, 0.25, 0.5],
  )
  assert_eq(matrix.probabilities(), [0.25, 0.0, 0.25, 0.0, 0.5, 0.0])
  // Marginalize wire 0:
  //   P(0) = 0.25 + 0.00 + 0.25 = 0.5
  //   P(1) = 0.00 + 0.50 + 0.00 = 0.5
  assert_eq(matrix.marginal_probabilities([0]), [0.5, 0.5])
  // Marginalize wire 1:
  //   P(0) = 0.25 + 0.00 = 0.25
  //   P(1) = 0.00 + 0.50 = 0.5
  //   P(2) = 0.25 + 0.00 = 0.25
  assert_eq(matrix.marginal_probabilities([1]), [0.25, 0.5, 0.25])
  // Reorder the wires as [1, 0]. Output digits now put the qutrit first:
  //   basis:        |00> |01> |10> |11> |20> |21>
  //   probability:  0.25  0.00  0.00  0.50  0.25  0.00
  assert_eq(matrix.marginal_probabilities([1, 0]), [
    0.25, 0.0, 0.0, 0.5, 0.25, 0.0,
  ])
  // Selecting all wires in their original order keeps the full distribution.
  assert_eq(matrix.marginal_probabilities([0, 1]), matrix.probabilities())
  // Selecting no wires sums every basis probability into the single empty outcome.
  assert_eq(matrix.marginal_probabilities([]), [1.0])
}
