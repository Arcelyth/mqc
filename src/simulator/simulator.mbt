///|
/// Execute programs using a backend state implementation.
struct Simulator[S] {
  label : String
  initialize : (Array[UInt32]) -> S raise @error.QError
}

///|
pub fn[S] Simulator::new(
  name : String,
  initialize : (Array[UInt32]) -> S raise @error.QError,
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
  initial_state? : S,
) -> TrialResult[S] raise @error.QError {
  self.execute(program, initial_state?)
}

///|
/// Deliver a state snapshot after each instruction without retaining all steps.
pub fn[S : SimulationState] Simulator::simulate_steps(
  self : Simulator[S],
  program : @circuit.Program,
  visit : (StepResult[S]) -> Unit raise @error.QError,
  initial_state? : S,
) -> TrialResult[S] raise @error.QError {
  self.execute(program, visit~, initial_state?)
}

///|
fn[S : SimulationState] Simulator::execute(
  self : Simulator[S],
  program : @circuit.Program,
  visit? : (StepResult[S]) -> Unit raise @error.QError,
  initial_state? : S,
) -> TrialResult[S] raise @error.QError {
  let dim = program.dim()
  let state = match initial_state {
    Some(state) => state.copy()
    None => (self.initialize)(dim)
  }
  if state.dim() != dim {
    raise @error.QError::RegisterMismatch
  }
  state.validate()

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
) -> Array[Result[TrialResult[S], @error.QError]] {
  programs.map(fn(program) {
    Ok(self.simulate(program)) catch {
      error => Err(error)
    }
  })
}
