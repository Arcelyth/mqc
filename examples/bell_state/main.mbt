///|
using @mqc {
  h,
  cnot,
  measure,
  type Circuit,
  type QubitId,
  type StateVectorSimulator,
}

///|
fn main {
  try! measure_bell()
}

///|
fn measure_bell() -> Unit raise @mqc.QuantumError {
  let a = QubitId(0UL)
  let b = QubitId(1UL)
  let bell = Circuit::from_op([h(a), cnot(a, b), measure([a, b], key="bell")])

  let simulator = StateVectorSimulator::new()
  let result = simulator.run(bell, repetitions=100)
  show_result(result)
}

///|
fn show_result(result : @mqc.SamplerResult) -> Unit raise @mqc.QuantumError {
  let (shots, _, _) = result.records.shape()
  let mut zeros = 0
  let mut ones = 0
  for shot in 0..<shots {
    match (result.records.get(shot, 0, 0), result.records.get(shot, 0, 1)) {
      (Some(0), Some(0)) => zeros += 1
      (Some(1), Some(1)) => ones += 1
      _ => raise @mqc.QuantumError::InvalidState("unexpected Bell measurement")
    }
  }

  println("Bell pair (\{shots} shots):")
  println("00: \{zeros}")
  println("11: \{ones}")
}
