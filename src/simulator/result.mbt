///|
pub using @result {
  type ExecutionResult,
  type ExecutionStatus,
  type ExperimentResult,
  type ResultError,
  type ResultData,
  trait ResultValue,
}

///|
/// Measurement results produced by sampling a quantum program.
/// An if_else block uses as many columns as its wider arm. Unused trailing
/// columns in the selected arm contain -1, outside the range of basis digits.
pub(all) struct SamplerResult {
  params : ParamBinding
  records : MeasurementRecords
}

///|
pub fn SamplerResult::new(
  params~ : ParamBinding = ParamBinding::empty(),
  records : @maths.Array3[Int32],
) -> SamplerResult {
  { params, records: { digits: records, layouts: [], }, }
}

///|
/// Retrieve the occurrences of a key in each shot.
/// See MeasurementRecords::for_key for the digit order.
pub fn SamplerResult::records_for(
  self : SamplerResult,
  key : String,
) -> Array[Array[Array[Int32]]] {
  self.records.for_key(key)
}

///|
pub impl Show for SamplerResult with fn output(self, logger) {
  self.records.output(logger)
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

///|
pub extend SamplerResult with Show::{output, to_string}
