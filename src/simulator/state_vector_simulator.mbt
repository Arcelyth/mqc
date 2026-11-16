///|
struct StateVectorSimulator {
  random : @random.Rand
  engine : Simulator[StateVectorState]
}

///|
pub fn StateVectorSimulator::new(seed? : UInt64) -> StateVectorSimulator {
  let random = match seed {
    Some(value) =>
      @random.Rand::chacha8(
        seed=Bytes::makei(32, fn(i) { (value >> (i % 8 * 8)).to_byte() }),
      )
    None => @random.Rand()
  }
  {
    random,
    engine: Simulator::new("statevector", shape => {
      @result_data.StateVectorState::new(shape, seed=random.uint64())
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
) -> TrialResult[StateVectorState] raise @circuit.QuantumError {
  self.engine.simulate(program)
}

///|
pub fn StateVectorSimulator::simulate_steps(
  self : StateVectorSimulator,
  program : @circuit.Program,
  visit : (StepResult[StateVectorState]) -> Unit raise @circuit.QuantumError,
) -> TrialResult[StateVectorState] raise @circuit.QuantumError {
  self.engine.simulate_steps(program, visit)
}

///|
pub fn StateVectorSimulator::simulate_batch(
  self : StateVectorSimulator,
  programs : Array[@circuit.Program],
) -> Array[Result[TrialResult[StateVectorState], @circuit.QuantumError]] {
  self.engine.simulate_batch(programs)
}

///|
pub impl Sampler for StateVectorSimulator with fn run(
  self,
  program,
  repetitions?,
) -> SamplerResult raise @circuit.QuantumError {
  let repetitions = repetitions.unwrap_or(1)
  if repetitions < 0 {
    raise @circuit.InvalidState("repetitions must be nonnegative")
  }

  let targets : Array[Int32] = []
  let mut measuring = false
  let mut terminal = true
  // Collects every measured wire into targets
  for instruction in program.instructions() {
    if instruction.effect().measurement_key() is Some(_) {
      measuring = true
      for wire in instruction.targets() {
        targets.push(wire)
      }
    } else if measuring {
      terminal = false
    }
  }

  let width = targets.length()
  if width == 0 {
    raise @circuit.InvalidState("run requires a measurement")
  }
  if repetitions > 2147483647 / width {
    raise @circuit.SizeLimit(2147483647)
  }

  if !terminal {
    return self.run_shots(program, repetitions, width)
  }

  // Fast path for terminal measurement.
  let state = @result_data.evolve(program)
  let probabilities = state.probabilities()
  let mut total = 0.0
  for i in 0..<probabilities.length() {
    total += probabilities[i]
    probabilities[i] = total
  }
  let shape = program.shape()
  let strides = shape.strides()
  let records = @maths.Array3::make(repetitions, 1, width, 0)
  for shot in 0..<repetitions {
    let draw = self.random.double() * total
    let mut lo = 0
    let mut hi = probabilities.length() - 1
    while lo < hi {
      let mid = lo + (hi - lo) / 2
      if draw < probabilities[mid] {
        hi = mid
      } else {
        lo = mid + 1
      }
    }
    for column, wire in targets {
      ignore(
        records.set(
          shot,
          0,
          column,
          lo / strides[wire] % shape[wire].reinterpret_as_int(),
        ),
      )
    }
  }
  SamplerResult::new(records)
}

///|
/// Execute each shot separately when measurements affect later gates.
fn StateVectorSimulator::run_shots(
  self : StateVectorSimulator,
  program : @circuit.Program,
  repetitions : Int32,
  width : Int32,
) -> SamplerResult raise @circuit.QuantumError {
  let records = @maths.Array3::make(repetitions, 1, width, 0)
  for shot in 0..<repetitions {
    let trial = self.simulate(program)
    for column in 0..<width {
      ignore(
        records.set(shot, 0, column, trial.records.get(0, 0, column).unwrap()),
      )
    }
  }
  SamplerResult::new(records)
}

///|
pub extend StateVectorSimulator with Sampler::{run}
