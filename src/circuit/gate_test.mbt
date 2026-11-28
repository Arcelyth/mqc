///|
fn expect_invalid_gate(
  make : () -> @circuit.Gate raise @circuit.CircuitError,
) -> Unit raise {
  let result = Ok(make()) catch { error => Err(error) }
  assert_true(result is Err(@circuit.CircuitError::InvalidGate(_)))
}

///|
test "unitary rejects incorrect size, nonunitary columns, and nonfinite entries" {
  let zero = @maths.Complex::real(0.0)
  let one = @maths.Complex::real(1.0)
  for
    matrix in [[one], [one, one, zero, zero], [one.scale(2.0), zero, zero, one]] {
    expect_invalid_gate(() => @circuit.Gate::unitary("bad", [2U], matrix))
  }
  for
    value in [
      @maths.Complex::real(1.0 / 0.0),
      @maths.Complex::new(0.0, 0.0 / 0.0),
    ] {
    expect_invalid_gate(() => {
      @circuit.Gate::unitary("bad", [2U], [value, zero, zero, one])
    })
  }
}

///|
test "monomial rejects invalid permutations and phases" {
  let one = @maths.Complex::real(1.0)
  for columns in [[0], [0, 0], [-1, 1], [0, 2]] {
    expect_invalid_gate(() => {
      @circuit.Gate::monomial("bad", [2U], columns, [one, one])
    })
  }
  for
    phases in [
      [one],
      [one, one.scale(2.0)],
      [one, @maths.Complex::real(1.0 / 0.0)],
    ] {
    expect_invalid_gate(() => {
      @circuit.Gate::monomial("bad", [2U], [0, 1], phases)
    })
    expect_invalid_gate(() => @circuit.Gate::diagonal("bad", [2U], phases))
  }
}

///|
test "controlled gate construction validates control shapes and values" {
  let gate = @circuit.Gate::diagonal(
    "I",
    [2U],
    Array::make(2, @maths.Complex::real(1.0)),
  )
  assert_eq(gate.controlled().dim(), [2U, 2U])
  assert_eq(gate.controlled(control_dimensions=[]).dim(), [2U])
  expect_invalid_gate(() => {
    gate.controlled(control_dimensions=[3U], control_values=[3U])
  })
  let mismatch = Ok(gate.controlled(control_values=[])) catch {
    error => Err(error)
  }
  assert_true(mismatch is Err(@circuit.CircuitError::TargetCount(1, 0)))
}
