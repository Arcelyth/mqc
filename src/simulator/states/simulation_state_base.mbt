///|
/// Common data for backends that need randomness and measurement records.
struct SimulationStateBase {
  rng : @splitmix.RandomState
  digits : Array[Int32]
  latest : Map[String, ArrayView[Int32]]
}

///|
pub fn SimulationStateBase::new(seed? : UInt64) -> SimulationStateBase {
  {
    rng: @splitmix.RandomState(
      seed=seed.unwrap_or_else(fn() { @random.Rand().uint64() }),
    ),
    digits: [],
    latest: Map([]),
  }
}

///|
/// Copy the records and RNG position into independent storage.
pub fn SimulationStateBase::copy(
  self : SimulationStateBase,
) -> SimulationStateBase {
  {
    rng: self.rng.clone(),
    digits: self.digits.copy(),
    latest: self.latest.copy(),
  }
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
  key? : String,
) -> Unit {
  let start = self.digits.length()
  for digit in digits {
    self.digits.push(digit)
  }
  if key is Some(name) {
    self.latest[name] = self.digits[start:]
  }
}

///|
/// Resolve chained guards in the order they were added. A missing key is an
/// error even when another guard would skip the operation.
fn SimulationStateBase::resolve(
  self : SimulationStateBase,
  effect : &@circuit.Effect,
) -> &@circuit.Effect? raise @error.QError {
  guard effect.try_conditional() is Some(guarded) else { return Some(effect) }
  let inner = self.resolve(guarded.inner)
  if guarded.condition.evaluate(self) {
    inner
  } else {
    None
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

///|
pub impl @circuit.MeasurementRecord for SimulationStateBase with fn latest(
  self,
  key,
) {
  guard self.latest.get(key) is Some(digits) else {
    raise @error.InvalidCondition("no measurement recorded for " + key)
  }
  digits
}

///|
pub extend SimulationStateBase with @circuit.MeasurementRecord::{latest}

///|
/// Run a branch on the same state so measurements inside it are available
/// to later instructions. 
/// Fill unused columns with -1 after the arm finishes.
fn SimulationStateBase::dispatch(
  self : SimulationStateBase,
  instruction : @circuit.Instruction[Int32],
  apply : (@circuit.Instruction[Int32]) -> Unit raise @error.QError,
) -> (&@circuit.Effect, Array[Int32])? raise @error.QError {
  match instruction {
    Operation(op) =>
      self.resolve(op.effect()).map(effect => (effect, op.targets()))
    ForLoop(block) => {
      for _ in 0..<block.count() {
        for child in block.body() {
          apply(child)
        }
      }
      None
    }
    IfElse(branch) => {
      let start = self.digits.length()
      for child in branch.select(self) {
        apply(child)
      }
      for _ in (self.digits.length() - start)..<instruction.record_width() {
        self.digits.push(-1)
      }
      None
    }
  }
}
