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
/// Print the shots for each record column, with commas between columns.
///
/// For two wires measured over five shots, `println(result)` might print this.
///
/// ```text
/// 10111, 10111
/// ```
pub impl Show for SamplerResult with fn output(self, logger) {
  let (shots, groups, width) = self.records.shape()
  if shots == 0 {
    return
  }
  for group in 0..<groups {
    for column in 0..<width {
      if group > 0 || column > 0 {
        logger.write_string(", ")
      }
      for shot in 0..<shots {
        let digit = self.records.get(shot, group, column).unwrap()
        if digit >= 0 && digit < 10 {
          logger.write_object(digit)
        } else {
          logger.write_string("[\{digit}]")
        }
      }
    }
  }
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
