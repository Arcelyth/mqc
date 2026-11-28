///|
/// Mutable state-vector execution data.
struct StateVectorState {
  base : SimulationStateBase
  vector : StateVector
  strides : Array[Int32]
}

///|
pub fn StateVectorState::new(
  dimensions : Array[UInt32],
  seed? : UInt64,
) -> StateVectorState {
  let vector = StateVector::zero(dimensions)
  {
    base: SimulationStateBase::new(seed?),
    vector,
    strides: vector.shape.strides(),
  }
}

///|
pub fn StateVectorState::from_state(
  state : StateVector,
  seed? : UInt64,
) -> StateVectorState raise StateError {
  validate_norm(state)
  {
    base: SimulationStateBase::new(seed?),
    vector: { shape: state.shape, re: state.re.copy(), im: state.im.copy(), },
    strides: state.shape.strides(),
  }
}

///|
pub fn StateVectorState::dim(self : StateVectorState) -> Array[UInt32] {
  self.vector.dim()
}

///|
pub fn StateVectorState::copy(self : StateVectorState) -> StateVectorState {
  let vector = self.vector
  {
    base: self.base.copy(),
    vector: { shape: vector.shape, re: vector.re.copy(), im: vector.im.copy(), },
    strides: self.strides,
  }
}

///|
/// Export a state vector that later execution cannot mutate.
pub fn StateVectorState::statevector(self : StateVectorState) -> StateVector {
  {
    shape: self.vector.shape,
    re: self.vector.re.copy(),
    im: self.vector.im.copy(),
  }
}

///|
pub fn StateVectorState::records(
  self : StateVectorState,
) -> @maths.Array3[Int32] {
  self.base.records()
}

///|
pub fn StateVectorState::validate(
  self : StateVectorState,
) -> Unit raise StateError {
  validate_norm(self.vector)
}

///|
/// Execute one instruction and change this state in place.
pub fn StateVectorState::apply(
  self : StateVectorState,
  instruction : @circuit.Instruction[Int32],
) -> Unit raise {
  check_instruction(instruction)
  guard self.base.dispatch(instruction, child => self.apply(child))
    is Some((effect, targets)) else {
    return
  }
  if effect.measurement_key() is Some(name) {
    self.validate()
    self.measure(targets, name)
  } else if effect.try_channel() is Some(channel) {
    self.apply_channel(channel, targets)
  } else {
    execute_gate(self.vector, self.strides, effect, targets)
  }
}

///|
/// Apply a channel to the target wires for one state-vector trajectory.
/// Draw a Kraus operator with probability equal to the squared norm of the state it produces.
///
/// $$
/// p_i = \bigl\|K_i |\psi\rangle\bigr\|^2.
/// $$
///
/// A unitary mixture supplies these probabilities directly. Sample a gate
/// from the mixture and apply it to the current state.
///
/// For a general Kraus channel, continue the shot with the normalized state
///
/// $$
/// |\psi'\rangle = \frac{K_i |\psi\rangle}{\sqrt{p_i}}.
/// $$
pub fn StateVectorState::apply_channel(
  self : StateVectorState,
  channel : @circuit.Channel,
  targets : Array[Int32],
) -> Unit raise StateError {
  let state = self.vector
  check_target_shape(channel.shape(), targets, state.shape)
  if channel.mixture_terms() is Some(terms) {
    let weights = terms.iter().map(term => term.0).collect()
    let index = sample_outcome(weights, self.base.draw())
    apply_local(
      state.re,
      state.im,
      state.shape,
      self.strides,
      terms[index].1.kernel(),
      targets,
    )
    return
  }
  let scratch = self.statevector()
  let kernels = channel.kernels().collect()
  let weights = []
  for kernel in kernels {
    state.re[:].blit_to(scratch.re)
    state.im[:].blit_to(scratch.im)
    apply_local(
      scratch.re,
      scratch.im,
      state.shape,
      self.strides,
      kernel,
      targets,
    )
    weights.push(scratch.norm_squared())
  }
  let outcome = sample_outcome(weights, self.base.draw())
  apply_local(
    state.re,
    state.im,
    state.shape,
    self.strides,
    kernels[outcome],
    targets,
  )
  let norm = weights[outcome].sqrt()
  for i in 0..<state.re.length() {
    state.re[i] /= norm
    state.im[i] /= norm
  }
}

///|
fn StateVectorState::measure(
  self : StateVectorState,
  targets : Array[Int32],
  key : String,
) -> Unit raise {
  let probabilities = self.vector.marginal_probabilities(targets)
  let outcome = sample_outcome(probabilities, self.base.draw())
  let digits = measurement_digits(self.vector.shape, targets, outcome)
  self.collapse_measurement(targets, digits, probabilities[outcome])
  self.base.record(digits[:], key~)
}

///|
/// Keep amplitudes matching the measured digits and divide by sqrt(probability).
fn StateVectorState::collapse_measurement(
  self : StateVectorState,
  targets : Array[Int32],
  digits : Array[Int32],
  probability : Double,
) -> Unit {
  let scale = 1.0 / probability.sqrt()
  for basis in 0..<self.vector.re.length() {
    if self.matches_digits(basis, targets, digits) {
      self.vector.re[basis] *= scale
      self.vector.im[basis] *= scale
    } else {
      self.vector.re[basis] = 0.0
      self.vector.im[basis] = 0.0
    }
  }
}

///|
fn StateVectorState::matches_digits(
  self : StateVectorState,
  basis : Int32,
  targets : Array[Int32],
  digits : Array[Int32],
) -> Bool {
  for i, wire in targets {
    if basis / self.strides[wire] % self.vector.shape[wire].reinterpret_as_int() !=
      digits[i] {
      return false
    }
  }
  true
}

///|
/// Return the columns measured under each key in this shot.
/// The returned spans can be retained across further changes to the state.
pub fn StateVectorState::measurement_layout(
  self : StateVectorState,
) -> MeasurementLayout {
  self.base.history.copy_ranges()
}
