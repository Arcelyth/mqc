///|
/// Choose an outcome from nonnegative weights using a uniform draw in [0, 1).
/// Scaling all weights by the same factor preserves the distribution.
fn sample_outcome(
  probabilities : Array[Double],
  draw : Double,
) -> Int32 raise StateError {
  if !(draw >= 0.0 && draw < 1.0) {
    raise InvalidState("outcome draw must be in [0, 1)")
  }
  let mut total = 0.0
  for probability in probabilities {
    if !(probability >= 0.0) {
      raise InvalidState("invalid outcome weight")
    }
    total += probability
  }
  if total <= 0.0 || total.is_nan() || total.is_inf() {
    raise InvalidState("invalid total outcome weight")
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
