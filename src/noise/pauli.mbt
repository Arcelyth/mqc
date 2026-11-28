///|
/// Flip a qubit with probability `p`. Otherwise leave it unchanged.
/// The probability must be between zero and one, inclusive.
///
/// $$
/// \mathcal{E}(\rho) = (1-p)\rho + p X\rho X.
/// $$
pub fn bit_flip(p : Double) -> @circuit.Channel raise @circuit.CircuitError {
  @circuit.Channel::mixture(
    [(1.0 - p, @gates.i()), (p, @gates.x())],
    name="BitFlip",
  )
}

///|
/// Apply a Pauli Z gate with probability `p`. This reverses the relative
/// phase between the two basis states. The probability must be in [0, 1].
///
/// $$
/// \mathcal{E}(\rho) = (1-p)\rho + p Z\rho Z.
/// $$
pub fn phase_flip(p : Double) -> @circuit.Channel raise @circuit.CircuitError {
  @circuit.Channel::mixture(
    [(1.0 - p, @gates.i()), (p, @gates.z())],
    name="PhaseFlip",
  )
}

///|
/// Apply a random Pauli error to a single qubit. The parameter `p` is the
/// total probability of an error. X, Y, and Z are equally likely when an
/// error occurs. The probability must be in [0, 1].
///
/// $$
/// \mathcal{E}(\rho) = (1-p)\rho + \frac{p}{3}(X\rho X + Y\rho Y + Z\rho Z).
/// $$
pub fn depolarize(p : Double) -> @circuit.Channel raise {
  if !(p >= 0.0 && p <= 1.0) {
    raise NoiseError::InvalidChannel(
      "depolarizing probability must be in [0, 1]",
    )
  }
  let weight = p / 3.0
  @circuit.Channel::mixture(
    [
      (1.0 - p, @gates.i()),
      (weight, @gates.x()),
      (weight, @gates.y()),
      (weight, @gates.z()),
    ],
    name="Depolarize",
  )
}
