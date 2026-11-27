///|
using @mqc {
  h,
  x,
  cnot,
  measure,
  type Circuit,
  type QubitId,
  type QError,
  type StateVectorSimulator,
}

///|
/// Build the oracle from its truth table. It flips the target when f(input) is one.
fn oracle(
  f0 : Bool,
  f1 : Bool,
  input : QubitId,
  target : QubitId,
) -> Array[@mqc.Operation[QubitId]] raise QError {
  let ops = []
  if f0 {
    ops.push(x(target))
  }
  if f0 != f1 {
    ops.push(cnot(input, target))
  }
  ops
}

///|
fn classify(
  query : (QubitId, QubitId) -> Array[@mqc.Operation[QubitId]] raise QError,
) -> String raise QError {
  let input = QubitId(0U)
  let target = QubitId(1U)
  // Prepare |+> on the input and |-> on the target. Flipping |-> changes its sign.
  let circuit = Circuit::from_op([h(input), x(target), h(target)])
  circuit.extend_ops(query(input, target))
  // The last Hadamard gives 0 for equal signs and 1 for opposite signs.
  circuit.extend_ops([h(input), measure([input], key="answer")])
  let result = StateVectorSimulator::new().run(circuit.compile(), repetitions=1)
  if result.records.get(0, 0, 0).unwrap() == 0 {
    "constant"
  } else {
    "balanced"
  }
}

///|
fn main {
  for
    (name, f0, f1) in [
      ("f(x) = 0", false, false),
      ("f(x) = 1", true, true),
      ("f(x) = x", false, true),
      ("f(x) = 1 - x", true, false),
    ] {
    let answer = try! classify((input, target) => oracle(f0, f1, input, target))
    println("\{name} is \{answer}")
  }
}
