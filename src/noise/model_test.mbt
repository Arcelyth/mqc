///|
/// An X gate on the target (position 1) also flips its neighbor (position 2).
/// The positions come from the order passed to Circuit::new.
struct FlipNeighbor {
  channel : @circuit.Channel
}

///|
impl @noise.NoiseModel for FlipNeighbor with fn after_gate(self, gate, targets) {
  if gate.name() == "X" && targets[0] == 1 {
    [(self.channel, [2])]
  } else {
    []
  }
}

///|
test "noise on another wire follows a guarded gate inside a counted loop" {
  let control = @circuit.QubitId(10UL)
  let target = @circuit.QubitId(20UL)
  let neighbor = @circuit.QubitId(30UL)
  let condition = @circuit.MeasurementCondition::Nonzero("m")
  let guarded = @circuit.Operation::new(@gates.x(), [target]).when(condition)
  let circuit = @circuit.Circuit::new([control, target, neighbor])
  let body = @circuit.Circuit::from_op([
    @circuit.measure([control], key="m"),
    guarded,
    @circuit.measure([target, neighbor]),
    @circuit.Operation::new(@gates.x(), [control]),
  ])
  circuit.for_loop(2, body)
  let noisy = circuit.with_noise(FlipNeighbor::{
    channel: @noise.bit_flip(1.0),
  })
  let simulator = @simulator.StateVectorSimulator::new(seed=3UL)
  // The compiled circuit still contains one loop with the noise inside its body.
  assert_eq(noisy.compile().length(), 1)
  // Each iteration records [control, target, neighbor]. The first reads control
  // as 0 and skips both flips. The X at the end sets control to 1, so the
  // second iteration flips the target and, in the noisy circuit, its neighbor.
  assert_eq(simulator.run(noisy.compile()).records.to_array(), [
    0, 0, 0, 1, 1, 1,
  ])
  assert_eq(simulator.run(circuit.compile()).records.to_array(), [
    0, 0, 0, 1, 1, 0,
  ])
}

///|
test "per-target noise applies the channel to each target of a gate" {
  let a = @circuit.QubitId(0UL)
  let b = @circuit.QubitId(1UL)
  let circuit = @circuit.Circuit::from_op([
    @circuit.Operation::new(@gates.cnot(), [a, b]),
    @circuit.measure([a, b]),
  ])
  let model = @noise.PerTargetNoise::new(@noise.bit_flip(1.0))
  let noisy = circuit.with_noise(model).compile()
  // CNOT leaves 00 unchanged. The two ones come from applying the bit-flip
  // channel once to each wire after CNOT.
  assert_eq(
    @simulator.DensityMatrixSimulator::new().run(noisy).records.to_array(),
    [1, 1],
  )
}
