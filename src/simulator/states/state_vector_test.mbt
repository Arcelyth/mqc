///|
test "marginal probabilities sum unmeasured wires and preserve requested digit order" {
  // The state vector contains 6 amplitudes:
  //   basis:        |00> |01> |02> |10> |11> |12>
  //   probability:  0.25  0.00  0.25  0.00  0.25  0.25
  //
  // Marginalize wire 0:
  //   P(0) = 0.25 + 0.00 + 0.25 = 0.5
  //   P(1) = 0.00 + 0.25 + 0.25 = 0.5
  let state = @states.StateVector::from_amplitudes([2U, 3U], [
    @maths.Complex::real(0.5),
    @maths.Complex::real(0.0),
    @maths.Complex::real(0.5),
    @maths.Complex::real(0.0),
    @maths.Complex::new(0.0, 0.5),
    @maths.Complex::real(0.5),
  ])
  assert_eq(state.marginal_probabilities([0]), [0.5, 0.5])

  // Marginalize wire 1:
  //   P(0) = 0.25 + 0.00 = 0.25
  //   P(1) = 0.00 + 0.25 = 0.25
  //   P(2) = 0.25 + 0.25 = 0.5
  assert_eq(state.marginal_probabilities([1]), [0.25, 0.25, 0.5])

  // Marginalize wires [1, 0], preserving the requested order.
  // The output basis order is |00>, |01>, |10>, |11>, |20>, |21>:
  //   P(00) = 0.25
  //   P(01) = 0.00
  //   P(10) = 0.00
  //   P(11) = 0.25
  //   P(20) = 0.25
  //   P(21) = 0.25
  assert_eq(state.marginal_probabilities([1, 0]), [
    0.25, 0.0, 0.0, 0.25, 0.25, 0.25,
  ])

  assert_eq(state.marginal_probabilities([]), [1.0])

  // Reject duplicate wire indices.
  let duplicate = Ok(state.marginal_probabilities([1, 1])) catch {
    error => Err(error)
  }
  assert_true(duplicate is Err(@error.QError::DuplicateQid(1)))

  // Reject wire indices outside the shape [2, 3].
  let invalid = Ok(state.marginal_probabilities([2])) catch {
    error => Err(error)
  }
  assert_true(invalid is Err(@error.QError::InvalidBasis(2)))
}
