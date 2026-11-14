///|
pub(open) trait ResultValue {
  /// A display name for current representation.
  fn type_name(Self) -> String
  /// Try to offer pure state.
  fn try_statevector(Self) -> StateVector? = _
}

///|
impl ResultValue with fn try_statevector(_self) -> StateVector? {
  None
}

///|
/// Named output data from one experiment. Only requested outputs are stored.
pub struct ResultData {
  values : @hashmap.HashMap[String, &ResultValue]
}

///|
pub fn ResultData::new() -> ResultData {
  { values: @hashmap.HashMap::new(), }
}

///|
/// Store the state produced by a simulation.
pub fn ResultData::from_statevector(state : StateVector) -> ResultData {
  { values: @hashmap.HashMap::singleton("statevector", state), }
}

///|
pub fn ResultData::statevector(self : ResultData) -> StateVector? {
  match self.values.get("statevector") {
    Some(value) => value.try_statevector()
    None => None
  }
}
