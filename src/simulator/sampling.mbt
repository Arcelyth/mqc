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
priv enum SamplingPlan {
  Terminal(Array[Int32], @states.MeasurementLayout)
  Shots(Int32)
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
  sample_channels~ : Bool = false,
) -> SamplingPlan raise SimulatorError {
  if repetitions < 0 {
    raise SimulatorError::InvalidState("repetitions must be nonnegative")
  }

  let targets : Array[Int32] = []
  let layout : @states.MeasurementLayout = Map([])
  let mut measuring = false
  let mut terminal = true
  let mut width = 0
  for instruction in program.instructions() {
    let count = instruction.record_width()
    if count > 2147483647 - width {
      raise SimulatorError::SizeLimit(2147483647)
    }
    width += count
  }

  if width == 0 {
    raise SimulatorError::InvalidState("run requires a measurement")
  }
  if repetitions > 2147483647 / width {
    raise SimulatorError::SizeLimit(2147483647)
  }

  for instruction in program.instructions(expand_loops=true) {
    guard instruction is Operation(op) && op.effect().try_conditional() is None else {
      terminal = false
      break
    }
    if op.effect().measurement_key() is Some(key) {
      let wires = op.targets()
      layout.get_or_init(key, () => []).push((targets.length(), wires.length()))
      measuring = true
      for wire in wires {
        targets.push(wire)
      }
    } else if measuring ||
      (sample_channels && op.effect().try_channel() is Some(_)) {
      terminal = false
      break
    }
  }

  if terminal {
    Terminal(targets, layout)
  } else {
    Shots(width)
  }
}

///|
/// Sample the final distribution without collapsing or rerunning the state.
fn sample_terminal(
  probabilities : Array[Double],
  program : @circuit.Program,
  targets : Array[Int32],
  layout : @states.MeasurementLayout,
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
  {
    records: { digits: records, layouts: [layout], },
    params: ParamBinding::empty(),
  }
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
  measurement_layout : (S) -> @states.MeasurementLayout,
) -> SamplerResult raise {
  let records = @maths.Array3::make(repetitions, 1, width, 0)
  let layouts = []
  for shot in 0..<repetitions {
    let trial = engine.simulate(program)
    layouts.push(measurement_layout(trial.state))
    for column in 0..<width {
      ignore(
        records.set(shot, 0, column, trial.records.get(0, 0, column).unwrap()),
      )
    }
  }
  { records: { digits: records, layouts, }, params: ParamBinding::empty(), }
}
