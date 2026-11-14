///|
pub using @result {
  type ExecutionResult,
  type ExecutionStatus,
  type ExperimentResult,
  type ResultError,
}

///|
pub(all) struct SamplerResult {
  params : ParamBinding
  records : @maths.Array3[Int32]
}

///|
pub fn SamplerResult::new(
  params~ : ParamBinding = ParamBinding::empty(),
  records : @maths.Array3[Int32],
) -> SamplerResult {
  { params, records, }
}
