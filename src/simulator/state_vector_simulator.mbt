///|
struct StateVectorSimulator {
  random : @random.Rand
  engine : Simulator[StateVectorState]
}

///|
pub fn StateVectorSimulator::new(seed? : UInt64) -> StateVectorSimulator {
  let random = simulator_random(seed)
  {
    random,
    engine: Simulator::new("statevector", shape => {
      @states.StateVectorState::new(shape, seed=random.uint64())
    }),
  }
}

///|
pub fn StateVectorSimulator::simulator(
  self : StateVectorSimulator,
) -> Simulator[StateVectorState] {
  self.engine
}

///|
pub fn StateVectorSimulator::name(self : StateVectorSimulator) -> String {
  self.engine.name()
}

///|
pub fn StateVectorSimulator::simulate(
  self : StateVectorSimulator,
  program : @circuit.Program,
  initial_state? : StateVectorState,
) -> TrialResult[StateVectorState] raise @error.QError {
  self.engine.simulate(program, initial_state?)
}

///|
pub fn StateVectorSimulator::simulate_steps(
  self : StateVectorSimulator,
  program : @circuit.Program,
  visit : (StepResult[StateVectorState]) -> Unit raise @error.QError,
  initial_state? : StateVectorState,
) -> TrialResult[StateVectorState] raise @error.QError {
  self.engine.simulate_steps(program, visit, initial_state?)
}

///|
pub fn StateVectorSimulator::simulate_batch(
  self : StateVectorSimulator,
  programs : Array[@circuit.Program],
) -> Array[Result[TrialResult[StateVectorState], @error.QError]] {
  self.engine.simulate_batch(programs)
}

///|
pub impl Sampler for StateVectorSimulator with fn run(
  self,
  program,
  repetitions?,
) -> SamplerResult raise @error.QError {
  let repetitions = repetitions.unwrap_or(1)
  let (targets, terminal) = sampling_plan(program, repetitions)
  if terminal {
    sample_terminal(
      @states.evolve(program).probabilities(),
      program,
      targets,
      repetitions,
      self.random,
    )
  } else {
    sample_shots(self.engine, program, repetitions, targets.length())
  }
}

///|
pub extend StateVectorSimulator with Sampler::{run}
