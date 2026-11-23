///|
test "Pauli noise channels assign the total error probability to the requested gates" {
  let cases = [
    (@noise.bit_flip(0.375), [("I", 0.625), ("X", 0.375)]),
    (@noise.phase_flip(0.375), [("I", 0.625), ("Z", 0.375)]),
    (
      @noise.depolarize(0.375),
      [("I", 0.625), ("X", 0.125), ("Y", 0.125), ("Z", 0.125)],
    ),
  ]
  for (channel, expected) in cases {
    let terms = channel.mixture_terms().unwrap()
    assert_eq(
      terms.iter().map(term => (term.1.name(), term.0)).collect(),
      expected,
    )
  }
}
