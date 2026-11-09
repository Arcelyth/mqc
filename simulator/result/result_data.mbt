///|
pub(open) trait ResultValue {
  /// A display name for current representation.
  fn type_name(Self) -> String
  /// Try to offer pure state.
  fn try_statevector(Self) -> @result_data.StateVector? = _
}

///|
impl ResultValue with fn try_statevector(_self) -> @result_data.StateVector? {
  None
}

///|
/// Named output data from one experiment. Only requested outputs are stored.
struct ResultData {
  values : @hashmap.HashMap[String, &ResultValue]
}

///|
pub fn ResultData::new() -> ResultData {
  { values: @hashmap.HashMap::new(), }
}
