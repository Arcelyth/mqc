///|
/// Helper for adding parameter names. 
fn add_names(
  names : @hashset.HashSet[String],
  additional : Array[String],
) -> @hashset.HashSet[String] {
  let mut result = names
  for name in additional {
    result = result.add(name)
  }
  result
}
