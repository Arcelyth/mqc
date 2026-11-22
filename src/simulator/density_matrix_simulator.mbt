///|
struct DensityMatrixSimulator {
  random : @random.Rand
  engine : Simulator[DensityMatrixState]
}

///|
pub fn DensityMatrixSimulator::new(seed? : UInt64) -> DensityMatrixSimulator {
  let random = simulator_random(seed)
  {
    random,
    engine: Simulator::new("densitymatrix", dimensions => {
      DensityMatrixState::new(dimensions, seed=random.uint64())
    }),
  }
}

///|
pub fn DensityMatrixSimulator::simulator(
  self : DensityMatrixSimulator,
) -> Simulator[DensityMatrixState] {
  self.engine
}

///|
pub fn DensityMatrixSimulator::name(self : DensityMatrixSimulator) -> String {
  self.engine.name()
}

///|
/// Execute one trial, optionally starting from a copy of a supplied mixed state.
pub fn DensityMatrixSimulator::simulate(
  self : DensityMatrixSimulator,
  program : @circuit.Program,
  initial_state? : DensityMatrixState,
) -> TrialResult[DensityMatrixState] raise @error.QError {
  self.engine.simulate(program, initial_state?)
}

///|
pub fn DensityMatrixSimulator::simulate_steps(
  self : DensityMatrixSimulator,
  program : @circuit.Program,
  visit : (StepResult[DensityMatrixState]) -> Unit raise @error.QError,
  initial_state? : DensityMatrixState,
) -> TrialResult[DensityMatrixState] raise @error.QError {
  self.engine.simulate_steps(program, visit, initial_state?)
}

///|
pub fn DensityMatrixSimulator::simulate_batch(
  self : DensityMatrixSimulator,
  programs : Array[@circuit.Program],
) -> Array[Result[TrialResult[DensityMatrixState], @error.QError]] {
  self.engine.simulate_batch(programs)
}

///|
/// Terminal measurements reuse one final distribution. Other circuits run once per shot.
pub impl Sampler for DensityMatrixSimulator with fn run(
  self,
  program,
  repetitions?,
) -> SamplerResult raise @error.QError {
  let repetitions = repetitions.unwrap_or(1)
  match sampling_plan(program, repetitions) {
    Terminal(targets) =>
      sample_terminal(
        density_terminal_probabilities(program),
        program,
        targets,
        repetitions,
        self.random,
      )
    Shots(width) => sample_shots(self.engine, program, repetitions, width)
  }
}

///|
/// Evolve the density matrix without collapsing terminal measurements or drawing randomness.
fn density_terminal_probabilities(
  program : @circuit.Program,
) -> Array[Double] raise @error.QError {
  let state = DensityMatrixState::new(program.dim(), seed=0UL)
  for instruction in program.instructions() {
    if instruction is Operation(op) && op.effect().measurement_key() is Some(_) {
      if !op.effect().parameters().is_empty() {
        raise @error.InvalidState("unbound parameters are not supported")
      }
    } else {
      state.apply(instruction)
    }
  }
  state.validate()
  state.probabilities()
}

///|
pub extend DensityMatrixSimulator with Sampler::{run}
