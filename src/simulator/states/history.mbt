///|
/// Measurements collected during one circuit execution. Each key identifies
/// the column ranges where its measured digits were appended.
priv struct MeasurementHistory {
  /// Outcomes in measurement order, with each measurement’s digits in target order.
  /// If "m" returns [1, 0] and then [1], digits contains [1, 0, 1].
  /// Unused columns from branches or loops contain -1.
  digits : Array[Int32]
  /// Each key maps to one (start, width) pair per measurement, in execution order.
  /// In the example above, ranges["m"] is [(0, 2), (2, 1)].
  ranges : MeasurementLayout
}

///|
fn MeasurementHistory::new() -> MeasurementHistory {
  { digits: [], ranges: Map([]), }
}

///|
fn MeasurementHistory::copy(self : MeasurementHistory) -> MeasurementHistory {
  { digits: self.digits.copy(), ranges: self.copy_ranges(), }
}

///|
fn MeasurementHistory::copy_ranges(
  self : MeasurementHistory,
) -> MeasurementLayout {
  self.ranges.map(fn(_, spans) { spans.copy() })
}

///|
fn MeasurementHistory::append(
  self : MeasurementHistory,
  digits : ArrayView[Int32],
  key? : String,
) -> Unit {
  let start = self.digits.length()
  for digit in digits {
    self.digits.push(digit)
  }
  if key is Some(name) {
    self.ranges.get_or_init(name, () => []).push((start, digits.length()))
  }
}

///|
fn MeasurementHistory::to_array3(
  self : MeasurementHistory,
) -> @maths.Array3[Int32] {
  @maths.Array3::makei(1, 1, self.digits.length(), fn(_, _, i) {
    self.digits[i]
  })
}

///|
impl @circuit.MeasurementRecord for MeasurementHistory with fn latest(self, key) {
  guard self.ranges.get(key) is Some(spans) else {
    raise @error.InvalidCondition("no measurement recorded for " + key)
  }
  let (start, width) = spans[spans.length() - 1]
  self.digits[start:start + width]
}

///|
/// Keep subsequent measurements at the same column in every shot. Padding
/// belongs only to the flat record and has no measurement key.
fn MeasurementHistory::pad(
  self : MeasurementHistory,
  start : Int32,
  width : Int32,
) -> Unit {
  for _ in (self.digits.length() - start)..<width {
    self.digits.push(-1)
  }
}

///|
/// For each measurement key, the spans give the start column and width of
/// each occurrence in execution order.
pub type MeasurementLayout = Map[String, Array[(Int32, Int32)]]
