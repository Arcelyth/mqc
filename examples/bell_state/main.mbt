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
  let program = bell.compile(name="Bell pair")
  let result = simulator.run(program, repetitions=100)
  show_result(result)
}

///|
fn show_result(result : @mqc.SamplerResult) -> Unit raise @mqc.QuantumError {
  let (shots, _, _) = result.records.shape()
  let counts = result.records.histogram("bell")
  let zeros = counts.get_or_default([0, 0], 0)
  let ones = counts.get_or_default([1, 1], 0)
  if zeros + ones != shots {
    raise @mqc.QuantumError::InvalidState("unexpected Bell measurement")
  }

  println("Bell pair (\{shots} shots):")
  println("00: \{zeros}")
  println("11: \{ones}")
}
