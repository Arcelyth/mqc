///|
fn simulator_random(seed : UInt64?) -> @random.Rand {
  match seed {
    Some(value) =>
      @random.Rand::chacha8(
        seed=Bytes::makei(32, fn(i) { (value >> (i % 8 * 8)).to_byte() }),
      )
    None => @random.Rand()
  }
}

///|
/// Analyze the program and determine its measurement sampling strategy.
///
/// Returns the measured wires in instruction order and whether all
/// measurements are terminal. A program with non-measurement instructions
/// after its first measurement requires independent execution for each shot.
fn sampling_plan(
  program : @circuit.Program,
  repetitions : Int32,
) -> (Array[Int32], Bool) raise @error.QError {
  if repetitions < 0 {
    raise @error.QError::InvalidState("repetitions must be nonnegative")
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
    raise @error.QError::InvalidState("run requires a measurement")
  }
  if repetitions > 2147483647 / width {
    raise @error.QError::SizeLimit(2147483647)
  }

  (targets, terminal)
}

///|
/// Sample the final distribution without collapsing or rerunning the state.
fn sample_terminal(
  probabilities : Array[Double],
  program : @circuit.Program,
  targets : Array[Int32],
  repetitions : Int32,
  random : @random.Rand,
) -> SamplerResult {
  let mut total = 0.0
  for i in 0..<probabilities.length() {
    total += probabilities[i]
    probabilities[i] = total
  }
  let shape = program.shape()
  let strides = shape.strides()
  let records = @maths.Array3::make(repetitions, 1, targets.length(), 0)
  for shot in 0..<repetitions {
    let draw = random.double() * total
    let basis = sample_basis(probabilities, draw)
    for column, wire in targets {
      ignore(
        records.set(
          shot,
          0,
          column,
          basis / strides[wire] % shape[wire].reinterpret_as_int(),
        ),
      )
    }
  }
  SamplerResult::new(records)
}

///|
/// Find the first cumulative probability greater than the sampled value.
fn sample_basis(probabilities : Array[Double], draw : Double) -> Int32 {
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
  lo
}

///|
/// Restart execution for each shot when a measurement affects later gates.
fn[S : SimulationState] sample_shots(
  engine : Simulator[S],
  program : @circuit.Program,
  repetitions : Int32,
  width : Int32,
) -> SamplerResult raise @error.QError {
  let records = @maths.Array3::make(repetitions, 1, width, 0)
  for shot in 0..<repetitions {
    let trial = engine.simulate(program)
    for column in 0..<width {
      ignore(
        records.set(shot, 0, column, trial.records.get(0, 0, column).unwrap()),
      )
    }
  }
  SamplerResult::new(records)
}
