///|
/// Records of measurement results from repeated runs of a circuit.
pub struct MeasurementRecords {
  digits : @maths.Array3[Int32]
  priv layouts : Array[@states.MeasurementLayout]
}

///|
/// Return the digit at this position, or None if it is out of bounds.
pub fn MeasurementRecords::get(
  self : MeasurementRecords,
  shot : Int32,
  group : Int32,
  column : Int32,
) -> Int32? {
  self.digits.get(shot, group, column)
}

///|
/// Return (shots, groups, columns).
pub fn MeasurementRecords::shape(
  self : MeasurementRecords,
) -> (Int32, Int32, Int32) {
  self.digits.shape()
}

///|
/// Return a flat copy of the digits, including padding.
pub fn MeasurementRecords::to_array(self : MeasurementRecords) -> Array[Int32] {
  self.digits.to_array()
}

///|
fn MeasurementRecords::layout(
  self : MeasurementRecords,
  shot : Int32,
) -> @states.MeasurementLayout {
  // Terminal measurements share a single layout.
  self.layouts[if self.layouts.length() == 1 { 0 } else { shot }]
}

///|
/// Return each run’s measurements for the key. Runs that skipped it have an empty list.
pub fn MeasurementRecords::for_key(
  self : MeasurementRecords,
  key : String,
) -> Array[Array[Array[Int32]]] {
  let (shots, _, _) = self.digits.shape()
  Array::makei(shots, shot => {
    if self.layouts.is_empty() {
      return []
    }
    guard self.layout(shot).get(key) is Some(spans) else { return [] }
    spans.map(fn(span) {
      let (start, width) = span
      Array::makei(width, i => self.digits.get(shot, 0, start + i).unwrap())
    })
  })
}

///|
/// Print one line per key. A dash marks a missing digit.
pub impl Show for MeasurementRecords with fn output(self, logger) {
  if self.layouts.is_empty() {
    self.output_columns(logger)
    return
  }
  let (shots, _, _) = self.digits.shape()
  if shots == 0 {
    return
  }
  let keys : Map[String, Unit] = Map([])
  for layout in self.layouts {
    for key, _ in layout {
      keys[key] = ()
    }
  }
  let mut first = true
  for key, _ in keys {
    if !first {
      logger.write_string("\n")
    }
    first = false
    logger.write_string(key)
    logger.write_string("=")
    self.output_key(key, logger)
  }
}

///|
fn MeasurementRecords::output_key(
  self : MeasurementRecords,
  key : String,
  logger : &Logger,
) -> Unit {
  let widths : Array[Int32] = []
  for layout in self.layouts {
    if layout.get(key) is Some(spans) {
      for i, span in spans {
        let (_, width) = span
        if i == widths.length() {
          widths.push(width)
        } else {
          widths[i] = widths[i].max(width)
        }
      }
    }
  }
  let (shots, _, _) = self.digits.shape()
  for occurrence, width in widths {
    for target in 0..<width {
      if occurrence > 0 || target > 0 {
        logger.write_string(", ")
      }
      for shot in 0..<shots {
        if self.layout(shot).get(key) is Some(spans) &&
          spans.get(occurrence) is Some((start, count)) &&
          target < count {
          write_digit(logger, self.digits.get(shot, 0, start + target).unwrap())
        } else {
          logger.write_string("-")
        }
      }
    }
  }
}

///|
fn write_digit(logger : &Logger, digit : Int32) -> Unit {
  if digit >= 0 && digit < 10 {
    logger.write_object(digit)
  } else {
    logger.write_string("[\{digit}]")
  }
}

///|
fn MeasurementRecords::output_columns(
  self : MeasurementRecords,
  logger : &Logger,
) -> Unit {
  let (shots, groups, width) = self.digits.shape()
  if shots == 0 {
    return
  }
  for group in 0..<groups {
    for column in 0..<width {
      if group > 0 || column > 0 {
        logger.write_string(", ")
      }
      for shot in 0..<shots {
        let digit = self.digits.get(shot, group, column).unwrap()
        write_digit(logger, digit)
      }
    }
  }
}

///|
pub extend MeasurementRecords with Show::{output, to_string}
