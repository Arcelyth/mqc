///|
priv struct Measurement {
  key : String
  shape : @internal.Shape
}

///|
impl Effect for Measurement with fn name(_self) -> String {
  "Measure"
}

///|
impl Effect for Measurement with fn dim(self) -> Array[UInt32] {
  self.shape.to_array()
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
    Measurement::{
      key,
      shape: @internal.Shape::new(targets.map(fn(q) { q.dim() })),
    },
    targets,
  )
}
