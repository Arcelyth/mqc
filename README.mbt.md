# MQC

Quantum computing library for MoonBit.

## Getting Started

Installation: 
```bash
moon add Arcelyth/mqc
```

A simple example:
```moonbit
///|
using @mqc {h, measure, type Circuit, type QubitId, type StateVectorSimulator}

///|
fn main raise {
  let qubit = QubitId(0UL)
  let circuit = Circuit::from_op([h(qubit), measure([qubit], key="m")])
  println("Circuit:")
  println(circuit)

  let simulator = StateVectorSimulator::new()
  let result = simulator.run(circuit.compile(), repetitions=20)
  println("Results:")
  println(result)
}
```

output: 
```text
Circuit:
0: ───H───M("m")───
Results:
01010000010101010011
```

See more examples [here](./examples).

## LICENSE
[MIT](./LICENSE)
