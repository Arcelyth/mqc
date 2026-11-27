///|
using @mqc {
  x,
  z,
  h,
  ry,
  cnot,
  phase,
  measure,
  type Circuit,
  type QubitId,
  type StateVectorSimulator,
  type MeasurementCondition,
  type QError,
}

///|
fn main {
  try! teleport()
}

///|
fn teleport() -> Unit raise QError {
  let input = QubitId(0U)
  let alice = QubitId(1U)
  let bob = QubitId(2U)
  let angle = 1.2
  let ph = 0.7
  let circuit = Circuit::from_op([
    // Prepare unequal amplitudes with a relative phase on the input wire.
    ry(angle, input),
    phase(ph, input),
    // Alice and Bob share a Bell pair.
    h(alice),
    cnot(alice, bob),
    // Alice measures her two wires. Bob uses the two bits for his corrections.
    cnot(input, alice),
    h(input),
    measure([input], key="phase"),
    measure([alice], key="flip"),
    x(bob).when(MeasurementCondition::Nonzero("flip")),
    z(bob).when(MeasurementCondition::Nonzero("phase")),
    // Undo the input preparation on Bob's wire. The recovered state gives zero.
    phase(-ph, bob),
    ry(-angle, bob),
    measure([bob], key="check"),
  ])
  let shots = 256
  let records = StateVectorSimulator::new(seed=7UL).run(
      circuit.compile(),
      repetitions=shots,
    ).records
  let counts = [0, 0, 0, 0]
  for shot in 0..<shots {
    let phase_bit = records.get(shot, 0, 0).unwrap()
    let flip_bit = records.get(shot, 0, 1).unwrap()
    let check = records.get(shot, 0, 2).unwrap()
    if check != 0 {
      raise QError::InvalidState("receiver check failed on shot \{shot}")
    }
    counts[2 * phase_bit + flip_bit] += 1
  }

  println("Alice's bits  shots")
  for bits, count in counts {
    println("\{bits / 2}\{bits % 2}            \{count}")
  }
  println(
    "Bob measured zero after undoing the preparation in all \{shots} shots.",
  )
}
