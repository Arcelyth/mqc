///|
/// Binds parameters with values.
struct ParamBinding {
  values : @hashmap.HashMap[String, Double]
}

///|
pub fn ParamBinding::empty() -> ParamBinding {
  { values: @hashmap.HashMap::new(), }
}
