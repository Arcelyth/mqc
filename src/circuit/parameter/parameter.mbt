///|
/// A symbolic parameter with an identity independent of its display name.
struct Parameter {
  label : String
  id : ParameterId
}

///|
/// Create a parameter. Pass an existing ID to reuse its identity.
pub fn Parameter::new(name : String, id? : ParameterId) -> Parameter {
  { label: name, id: id.unwrap_or_else(ParameterId::new), }
}

///|
pub fn Parameter::name(self : Parameter) -> String {
  self.label
}

///|
/// Return the parameter's ID.
pub fn Parameter::id(self : Parameter) -> ParameterId {
  self.id
}

///|
pub impl Eq for Parameter with fn equal(self, other) {
  self.id == other.id
}

///|
pub impl Hash for Parameter with fn hash_combine(self, hasher) {
  Hash::hash_combine(self.id, hasher)
}

///|
pub impl Debug for Parameter with fn to_repr(self) {
  Debug::to_repr(self.label)
}

///|
pub fn Parameter::expr(self : Parameter) -> ParamExpr {
  Symbol(self)
}
