///|
pub using @result {
  type ExecutionResult,
  type ExecutionStatus,
  type ExperimentResult,
  type ResultError,
}

///|
/// Measurement results produced by sampling a quantum program.
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

///|
/// A state snapshot after the instruction at zero-based `instruction_index`.
pub(all) struct StepResult[S] {
  instruction_index : Int32
  state : S
}

///|
/// The final backend state and actual measurement records for one execution.
pub(all) struct TrialResult[S] {
  state : S
  params : ParamBinding
  records : @maths.Array3[Int32]
}
