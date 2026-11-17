///|
/// A quantum action on an ordered local wire shape such as `Gate`, `Channel`, and `Program`.
///
/// An effect describes an operation independently of the physical wires
/// it is applied to. Its local wire indices are mapped onto the enclosing
/// operation's target wires when it is added to a program or circuit.
pub(open) trait Effect {
  /// A label for display and error messages.
  fn measurement_key(Self) -> String? = _
  fn name(Self) -> String

  /// Returns the dimensions of the local quantum wires acted upon by
  /// this effect, in their logical order.
  ///
  /// Each element specifies the Hilbert-space dimension of one wire.
  /// For example, `[2, 2]` represents two qubits, while `[2, 3]`
  /// represents one qubit and one qutrit.
  ///
  /// The order is significant: `[2, 3]` and `[3, 2]` describe
  /// different ordered wire shapes.
  fn dim(Self) -> Array[UInt32]

  /// The number of local wires, not the product of their dimensions.
  fn arity(Self) -> Int32 = _

  /// Try to provide an exact unitary gate equivalent to this effect.
  fn try_unitary(Self) -> Gate? = _

  /// Try to provide an equivalent completely positive, trace-preserving 
  /// quantum channel.
  fn try_channel(Self) -> Channel? = _

  /// Try to decompose this effect into an equivalent quantum program.
  fn try_decompose(Self) -> Program? raise @error.QError = _

  /// Try to provide the adjoint as an effect with the same ordered shape.
  /// For a unitary, this is its inverse. Unbound symbols may stay symbolic.
  /// General noisy channels need not have an adjoint that is a valid effect.
  fn try_adjoint(Self) -> &Effect? raise @error.QError = _

  /// Free parameter names, without duplicates, in lexical order.
  /// Parameters let you build a circuit with values you will supply later, such as a rotation angle.
  fn parameters(Self) -> Array[String] = _
}

///|
impl Effect with fn arity(self) -> Int32 {
  self.dim().length()
}

///|
impl Effect with fn try_unitary(_self) -> Gate? {
  None
}

///|
impl Effect with fn try_channel(_self) -> Channel? {
  None
}

///|
impl Effect with fn try_decompose(_self) -> Program? raise @error.QError {
  None
}

///|
impl Effect with fn try_adjoint(_self) -> &Effect? raise @error.QError {
  None
}

///|
impl Effect with fn parameters(_self) -> Array[String] {
  []
}

///|
impl Effect with fn measurement_key(_self) -> String? {
  None
}
