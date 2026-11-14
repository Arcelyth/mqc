///|
pub(open) trait Simulator {
  /// Return the backend's display name for execution results.
  fn name(Self) -> String
  /// Execute one circuit.
  fn run(Self, @circuit.Program) -> ExecutionResult
  /// Execute a batch in input order. One failure must not stop later experiments.
  fn run_batch(Self, Array[@circuit.Program]) -> ExecutionResult = _
}

///|
impl Simulator with fn run_batch(self, circuits) -> ExecutionResult {
  let experiments = []
  for circuit in circuits {
    for experiment in self.run(circuit).results() {
      experiments.push(experiment)
    }
  }
  ExecutionResult::new(self.name(), experiments)
}
