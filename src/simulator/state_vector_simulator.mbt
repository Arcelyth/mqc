///|
struct StateVectorSimulator {
  random : @random.Rand
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
  { random, }
}

/// ===== Implement Simulator for StateVectorSimulator =====

///|
pub impl Simulator for StateVectorSimulator with fn name(_self) -> String {
  "statevector_simulator"
}

///|
pub impl Simulator for StateVectorSimulator with fn simulate(_self, program) -> StateVector raise @circuit.QuantumError {
  @result_data.evolve(program)
}

/// ===== ===== 

/// ===== Implement Sampler for StateVectorSimulator =====

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
  // Collects every measured wire into targets
  for instruction in program.instructions() {
    if instruction.effect().measurement_key() is Some(_) {
      for wire in instruction.targets() {
        targets.push(wire)
      }
    }
  }

  let width = targets.length()
  if width == 0 {
    raise @circuit.InvalidState("run requires a measurement")
  }
  if repetitions > 2147483647 / width {
    raise @circuit.SizeLimit(2147483647)
  }

  let state = @result_data.evolve(program)
  let probabilities = state.probabilities()
  let mut total = 0.0
  for i in 0..<probabilities.length() {
    total += probabilities[i]
    probabilities[i] = total
  }
  let shape = program.dimensions()
  let strides = Array::make(shape.length(), 1)
  let mut stride = 1
  for i = shape.length() - 1; i >= 0; i = i - 1 {
    strides[i] = stride
    stride *= shape[i].reinterpret_as_int()
  }
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

/// ===== =====

///|
pub extend StateVectorSimulator with Sampler::{run}

///|
pub extend StateVectorSimulator with Simulator::{name, simulate, simulate_batch}
