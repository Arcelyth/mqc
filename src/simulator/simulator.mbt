///|
/// A backend that exposes simulated states.
pub(open) trait Simulator {
  fn name(Self) -> String
  /// Return the pure state before terminal measurements.
  fn simulate(Self, @circuit.Program) -> StateVector raise @circuit.QuantumError
  /// Keep input order and record each failure without stopping later programs.
  fn simulate_batch(Self, Array[@circuit.Program]) -> ExecutionResult = _
}

///|
impl Simulator with fn simulate_batch(self, programs) -> ExecutionResult {
  let experiments = []
  for program in programs {
    let experiment = try {
      let state = self.simulate(program)
      ExperimentResult::completed(
        program,
        @result_data.ResultData::from_statevector(state),
      )
    } catch {
      error => ExperimentResult::failed(program, error)
    }
    experiments.push(experiment)
  }
  ExecutionResult::new(self.name(), experiments)
}
