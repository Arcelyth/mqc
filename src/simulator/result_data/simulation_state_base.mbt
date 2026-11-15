///|
/// Common data for backends that need randomness and measurement records.
struct SimulationStateBase {
  rng : @splitmix.RandomState
  digits : Array[Int32]
}

///|
pub fn SimulationStateBase::new(seed? : UInt64) -> SimulationStateBase {
  {
    rng: @splitmix.RandomState(
      seed=seed.unwrap_or_else(fn() { @random.Rand().uint64() }),
    ),
    digits: [],
  }
}

///|
/// Copy the records and RNG position into independent storage.
pub fn SimulationStateBase::copy(
  self : SimulationStateBase,
) -> SimulationStateBase {
  { rng: self.rng.clone(), digits: self.digits.copy(), }
}

///|
/// Draw a uniform value in [0, 1).
pub fn SimulationStateBase::draw(self : SimulationStateBase) -> Double {
  self.rng.next_double()
}

///|
/// Append measured digits in target order.
pub fn SimulationStateBase::record(
  self : SimulationStateBase,
  digits : ArrayView[Int32],
) -> Unit {
  for digit in digits {
    self.digits.push(digit)
  }
}

///|
/// Return an independent Array3 with axes (shot, occurrence, measured digit).
/// A single execution has shape (1, 1, digit count), including (1, 1, 0).
pub fn SimulationStateBase::records(
  self : SimulationStateBase,
) -> @maths.Array3[Int32] {
  @maths.Array3::makei(1, 1, self.digits.length(), fn(_, _, i) {
    self.digits[i]
  })
}
