///|
priv struct Measurement {
  key : String
  shape : Array[UInt32]
}

///|
impl Effect for Measurement with fn name(_self) -> String {
  "Measure"
}

///|
impl Effect for Measurement with fn dimensions(self) -> Array[UInt32] {
  self.shape.copy()
}

///|
impl Effect for Measurement with fn measurement_key(self) -> String? {
  Some(self.key)
}

///|
pub fn[Q : Qid] measure(
  targets : Array[Q],
  key~ : String = "m",
) -> Operation[Q] raise QuantumError {
  if targets.is_empty() || key == "" {
    raise InvalidState("measurement needs targets and a key")
  }
  Operation::new(
    Measurement::{ key, shape: targets.map(fn(q) { q.dimension() }), },
    targets,
  )
}
