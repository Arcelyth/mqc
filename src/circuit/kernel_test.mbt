///|
fn apply_kernel(
  kernel : &@circuit.LinearKernel,
  input : Array[@maths.Complex],
) -> Array[@maths.Complex] {
  let input_re = input.map(fn(z) { z.re })
  let input_im = input.map(fn(z) { z.im })
  let output_re = Array::make(kernel.size(), 0.0 / 0.0)
  let output_im = Array::make(kernel.size(), 0.0 / 0.0)
  kernel.apply({
    input_re: input_re[:],
    input_im: input_im[:],
    output_re: output_re.mut_view(),
    output_im: output_im.mut_view(),
  })
  Array::makei(kernel.size(), fn(i) {
    @maths.Complex::new(output_re[i], output_im[i])
  })
}

///|
fn assert_amplitudes(
  actual : Array[@maths.Complex],
  expected : Array[@maths.Complex],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i in 0..<actual.length() {
    assert_true((actual[i].re - expected[i].re).abs() < 1.0e-12)
    assert_true((actual[i].im - expected[i].im).abs() < 1.0e-12)
  }
}

///|
test "dense kernel applies complex row order and its adjoint restores input" {
  let s = 1.0 / 2.0.sqrt()
  let gate = @circuit.Gate::unitary("complex", [2U], [
    @maths.Complex::real(s),
    @maths.Complex::new(0.0, s),
    @maths.Complex::real(s),
    @maths.Complex::new(0.0, -s),
  ])
  let input = [@maths.Complex::new(1.0, 1.0), @maths.Complex::new(2.0, -1.0)]
  let output = apply_kernel(gate.kernel(), input)

  assert_amplitudes(output, [
    @maths.Complex::new(2.0 * s, 3.0 * s),
    @maths.Complex::new(0.0, -s),
  ])
  assert_amplitudes(apply_kernel(gate.kernel().adjoint(), output), input)
}

///|
test "kernel output is independent of mutations to gate constructor inputs" {
  let s = 1.0 / 2.0.sqrt()
  let shape = [2U]
  let matrix = [
    @maths.Complex::real(s),
    @maths.Complex::real(s),
    @maths.Complex::real(s),
    @maths.Complex::real(-s),
  ]
  let gate = @circuit.Gate::unitary("H", shape, matrix)
  shape[0] = 3U
  matrix[0] = @maths.Complex::real(99.0)
  let exported = gate.dim()
  exported[0] = 4U

  assert_amplitudes(
    apply_kernel(gate.kernel(), [
      @maths.Complex::real(1.0),
      @maths.Complex::real(0.0),
    ]),
    [@maths.Complex::real(s), @maths.Complex::real(s)],
  )
}

///|
test "monomial kernel preserves permutation phases, input ownership, and adjoints" {
  let shape = [3U]
  let columns = [2, 0, 1]
  let phases = [
    @maths.Complex::new(0.0, 1.0),
    @maths.Complex::real(1.0),
    @maths.Complex::real(-1.0),
  ]
  let gate = @circuit.Gate::monomial("cycle", shape, columns, phases)
  shape[0] = 2U
  columns[0] = 0
  phases[0] = @maths.Complex::real(0.0)

  let input = [
    @maths.Complex::new(1.0, 2.0),
    @maths.Complex::new(3.0, 4.0),
    @maths.Complex::new(5.0, 6.0),
  ]
  let output = apply_kernel(gate.kernel(), input)
  assert_amplitudes(output, [
    @maths.Complex::new(-6.0, 5.0),
    @maths.Complex::new(1.0, 2.0),
    @maths.Complex::new(-3.0, -4.0),
  ])
  assert_amplitudes(apply_kernel(gate.kernel().adjoint(), output), input)
}
