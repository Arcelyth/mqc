///|
/// Sample a marginal outcome. Ignore zero-probability outcomes at the edges.
fn measurement_outcome(
  probabilities : Array[Double],
  draw : Double,
) -> Int32 raise @error.QError {
  let total = probabilities.fold(init=0.0, (sum, probability) => {
    sum + probability
  })
  if total <= 0.0 || total.is_nan() || total.is_inf() {
    raise @error.InvalidState("invalid measurement probability")
  }
  let threshold = draw * total
  let mut cumulative = 0.0
  let mut last = 0
  for i, probability in probabilities {
    if probability > 0.0 {
      last = i
      cumulative += probability
      if threshold < cumulative {
        return i
      }
    }
  }
  last
}

///|
fn measurement_digits(
  shape : @internal.Shape,
  targets : Array[Int32],
  outcome : Int32,
) -> Array[Int32] {
  let digits = Array::make(targets.length(), 0)
  let mut remaining = outcome
  for i = targets.length() - 1; i >= 0; i = i - 1 {
    let dimension = shape[targets[i]].reinterpret_as_int()
    digits[i] = remaining % dimension
    remaining /= dimension
  }
  digits
}
