///|
#derive(Eq, Hash, Debug)
struct ParameterId(UInt64)

///|
let parameter_id_counter : Ref[UInt64] = Ref(0UL)

///|
fn ParameterId::new() -> ParameterId {
  let id = parameter_id_counter.val + 1UL
  guard id != 0UL else { abort("parameter ID space exhausted") }
  parameter_id_counter.val = id
  ParameterId(id)
}
