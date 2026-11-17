///|
pub(open) trait ResultValue {
  /// A display name for current representation.
  fn type_name(Self) -> String
  /// Try to offer pure state.
  fn try_statevector(Self) -> @states.StateVector? = _
  /// Try to offer a density matrix.
  fn try_density_matrix(Self) -> @states.DensityMatrix? = _
}

///|
impl ResultValue with fn try_statevector(_self) -> @states.StateVector? {
  None
}

///|
impl ResultValue with fn try_density_matrix(_self) -> @states.DensityMatrix? {
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
pub fn ResultData::from_statevector(state : @states.StateVector) -> ResultData {
  { values: @hashmap.HashMap::singleton("state_vector", state), }
}

///|
pub fn ResultData::statevector(self : ResultData) -> @states.StateVector? {
  match self.values.get("state_vector") {
    Some(value) => value.try_statevector()
    None => None
  }
}

///|
pub fn ResultData::from_density_matrix(
  state : @states.DensityMatrix,
) -> ResultData {
  { values: @hashmap.HashMap::singleton("density_matrix", state), }
}

///|
pub fn ResultData::density_matrix(self : ResultData) -> @states.DensityMatrix? {
  match self.values.get("density_matrix") {
    Some(value) => value.try_density_matrix()
    None => None
  }
}

///|
pub impl ResultValue for @states.StateVector with fn type_name(_self) -> String {
  "state_vector"
}

///|
pub impl ResultValue for @states.StateVector with fn try_statevector(self) -> @states.StateVector? {
  Some(self)
}

///|
pub impl ResultValue for @states.DensityMatrix with fn type_name(_self) -> String {
  "density_matrix"
}

///|
pub impl ResultValue for @states.DensityMatrix with fn try_density_matrix(self) -> @states.DensityMatrix? {
  Some(self)
}
