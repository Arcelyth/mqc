///|
/// Common data for backends that need randomness and measurement records.
struct SimulationStateBase {
  history : MeasurementHistory
  rng : @splitmix.RandomState
}

///|
pub fn SimulationStateBase::new(seed? : UInt64) -> SimulationStateBase {
  {
    rng: @splitmix.RandomState(
      seed=seed.unwrap_or_else(fn() { @random.Rand().uint64() }),
    ),
    history: MeasurementHistory::new(),
  }
}

///|
/// Copy the records and RNG position into independent storage.
pub fn SimulationStateBase::copy(
  self : SimulationStateBase,
) -> SimulationStateBase {
  { rng: self.rng.copy(), history: self.history.copy(), }
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
  self.history.append(digits, key?)
}

///|
/// Resolve chained guards in the order they were added. A missing key is an
/// error even when another guard would skip the operation.
fn SimulationStateBase::resolve(
  self : SimulationStateBase,
  effect : &@circuit.Effect,
) -> &@circuit.Effect? raise @circuit.CircuitError {
  guard effect.try_conditional() is Some(guarded) else { return Some(effect) }
  let inner = self.resolve(guarded.inner)
  if guarded.condition.evaluate(self.history) {
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
  self.history.to_array3()
}

///|
pub impl @circuit.MeasurementRecord for SimulationStateBase with fn latest(
  self,
  key,
) {
  @circuit.MeasurementRecord::latest(self.history, key)
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
  apply : (@circuit.Instruction[Int32]) -> Unit raise,
) -> (&@circuit.Effect, Array[Int32])? raise {
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
    WhileLoop(block) => {
      let start = self.history.digits.length()
      let mut iterations = 0
      while block.condition().evaluate(self.history) {
        if iterations == block.max_iterations() {
          raise StateError::IterationLimit(iterations)
        }
        for child in block.body() {
          apply(child)
        }
        iterations += 1
      }
      self.history.pad(start, instruction.record_width())
      None
    }
    IfElse(branch) => {
      let start = self.history.digits.length()
      for child in branch.select(self.history) {
        apply(child)
      }
      self.history.pad(start, instruction.record_width())
      None
    }
  }
}
