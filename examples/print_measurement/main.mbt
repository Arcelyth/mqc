///|
using @mqc {
  x,
  h,
  measure,
  type Circuit,
  type QubitId,
  type StateVectorSimulator,
}

///|
fn main {
  try! print_measurement()
}

///|
fn print_measurement() -> Unit raise {
  let a = QubitId(0U)
  let c = Circuit::from_op([x(a), h(a), measure([a])])

  let simulator = StateVectorSimulator::new()
  let program = c.compile(name="c")
  println("Circuit:")
  println(c)

  let result = simulator.run(program, repetitions=20)
  println("Results:")
  println(result)
}
