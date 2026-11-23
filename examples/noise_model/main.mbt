///|
using @mqc {
  x,
  measure,
  type Circuit,
  type QubitId,
  type StateVectorSimulator,
  type DensityMatrixSimulator,
  type Channel,
}

///|
fn main {
  try! compare_damping()
}

///|
fn compare_damping() -> Unit raise @mqc.QError {
  let q = QubitId(0UL)
  let preparation = Circuit::from_op([x(q)])
  let damping = Channel::amplitude_damp(0.25)
  let circuit = preparation.with_noise(@noise.PerTargetNoise::new(damping))

  // The density matrix includes both outcomes before any measurement.
  let density = DensityMatrixSimulator::new().simulate(circuit.compile())
  let exact = density.state.probabilities()

  // Each state-vector shot follows one trajectory. A zero means the qubit decayed.
  circuit.append(measure([q]))
  let shots = 4096
  let records = StateVectorSimulator::new(seed=7UL).run(
      circuit.compile(),
      repetitions=shots,
    ).records
  let counts = [0, 0]
  for digit in records.to_array() {
    counts[digit] += 1
  }
  for digit, count in counts {
    let expected = (exact[digit] * 100.0).round().to_int()
    let observed = (count.to_double() * 10000.0 / shots.to_double()).round() /
      100.0
    println(
      "Outcome \{digit}: expected \{expected}%, observed \{observed}% (\{count}/\{shots} shots)",
    )
  }
}
