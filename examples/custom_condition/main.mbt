///|
/// Demonstrates classical feed-forward using a custom parity condition.
/// Measures two qubits, evaluates whether their results differ, and
/// conditionally applies an X gate to a third qubit. 
/// The final measurement verifies that the output equals the 
/// XOR of the two input measurements.
using @mqc {
  x,
  h,
  measure,
  type Circuit,
  type QubitId,
  type StateVectorSimulator,
  trait Condition,
}

///|
struct Parity {
  left : String
  right : String
}

///|
/// Each key holds one measured bit. Their parity is odd when they differ.
impl Condition for Parity with fn evaluate(self, record) {
  record.latest(self.left)[0] != record.latest(self.right)[0]
}

///|
fn main {
  try! measure_parity()
}

///|
fn measure_parity() -> Unit raise @mqc.QuantumError {
  let a = QubitId(0UL)
  let b = QubitId(1UL)
  let output = QubitId(2UL)
  let odd = Parity::{ left: "a", right: "b", }
  let circuit = Circuit::from_op([
    h(a),
    h(b),
    measure([a], key="a"),
    measure([b], key="b"),
    x(output).when(odd),
    measure([output], key="parity"),
  ])
  let simulator = StateVectorSimulator::new(seed=1UL)
  let records = simulator.run(circuit.compile(), repetitions=8).records
  println("a b parity")
  for shot in 0..<8 {
    let a = records.get(shot, 0, 0).unwrap()
    let b = records.get(shot, 0, 1).unwrap()
    let parity = records.get(shot, 0, 2).unwrap()
    println("\{a} \{b} \{parity}")
  }
}
