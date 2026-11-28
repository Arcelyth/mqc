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
) -> TrialResult[StateVectorState] raise {
  self.engine.simulate(program, initial_state?)
}

///|
pub fn StateVectorSimulator::simulate_steps(
  self : StateVectorSimulator,
  program : @circuit.Program,
  visit : (StepResult[StateVectorState]) -> Unit raise,
  initial_state? : StateVectorState,
) -> TrialResult[StateVectorState] raise {
  self.engine.simulate_steps(program, visit, initial_state?)
}

///|
pub fn StateVectorSimulator::simulate_batch(
  self : StateVectorSimulator,
  programs : Array[@circuit.Program],
) -> Array[Result[TrialResult[StateVectorState], Error]] {
  self.engine.simulate_batch(programs)
}

///|
pub impl Sampler for StateVectorSimulator with fn run(
  self,
  program,
  repetitions?,
) -> SamplerResult raise {
  let repetitions = repetitions.unwrap_or(1)
  match sampling_plan(program, repetitions, sample_channels=true) {
    Terminal(targets, layout) =>
      sample_terminal(
        @states.evolve(program).probabilities(),
        program,
        targets,
        layout,
        repetitions,
        self.random,
      )
    Shots(width) =>
      sample_shots(
        self.engine,
        program,
        repetitions,
        width,
        StateVectorState::measurement_layout,
      )
  }
}

///|
pub extend StateVectorSimulator with Sampler::{run}
