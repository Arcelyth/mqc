///|
/// Execute programs using a backend state implementation.
struct Simulator[S] {
  label : String
  initialize : (Array[UInt32]) -> S raise @circuit.QuantumError
}

///|
pub fn[S] Simulator::new(
  name : String,
  initialize : (Array[UInt32]) -> S raise @circuit.QuantumError,
) -> Simulator[S] {
  { label: name, initialize, }
}

///|
pub fn[S] Simulator::name(self : Simulator[S]) -> String {
  self.label
}

///|
pub fn[S : SimulationState] Simulator::simulate(
  self : Simulator[S],
  program : @circuit.Program,
) -> TrialResult[S] raise @circuit.QuantumError {
  self.execute(program)
}

///|
/// Deliver a state snapshot after each instruction without retaining all steps.
pub fn[S : SimulationState] Simulator::simulate_steps(
  self : Simulator[S],
  program : @circuit.Program,
  visit : (StepResult[S]) -> Unit raise @circuit.QuantumError,
) -> TrialResult[S] raise @circuit.QuantumError {
  self.execute(program, visit~)
}

///|
fn[S : SimulationState] Simulator::execute(
  self : Simulator[S],
  program : @circuit.Program,
  visit? : (StepResult[S]) -> Unit raise @circuit.QuantumError,
) -> TrialResult[S] raise @circuit.QuantumError {
  let state = (self.initialize)(program.dim())
  let mut index = 0
  for instruction in program.instructions() {
    state.apply(instruction)
    if visit is Some(callback) {
      state.validate()
      callback({ instruction_index: index, state: state.copy(), })
    }
    index += 1
  }
  state.validate()
  { state, params: ParamBinding::empty(), records: state.records(), }
}

///|
/// Keep typed trials and errors in input order, continuing after failures.
pub fn[S : SimulationState] Simulator::simulate_batch(
  self : Simulator[S],
  programs : Array[@circuit.Program],
) -> Array[Result[TrialResult[S], @circuit.QuantumError]] {
  programs.map(fn(program) {
    Ok(self.simulate(program)) catch {
      error => Err(error)
    }
  })
}
