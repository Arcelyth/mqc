///|
/// One execution's result.
struct ExperimentResult {
  /// Display name of the submitted program.
  program_name : String
  /// Ordered input dimensions.
  shape : @internal.Shape
  /// Explicitly saved values from a successful experiment.
  outputs : ResultData
  /// Error cause when current experiment failed.
  failure : @error.QError?
}

///|
/// Record a successful execution of this program with its requested outputs.
pub fn ExperimentResult::completed(
  program : @circuit.Program,
  data : ResultData,
) -> ExperimentResult {
  {
    program_name: program.name(),
    shape: program.shape(),
    outputs: data,
    failure: None,
  }
}

///|
/// Return the input program's display name.
pub fn ExperimentResult::name(self : ExperimentResult) -> String {
  self.program_name
}

///|
pub fn ExperimentResult::dim(self : ExperimentResult) -> Array[UInt32] {
  self.shape.to_array()
}

///|
/// Report whether current experiment completed.
pub fn ExperimentResult::is_completed(self : ExperimentResult) -> Bool {
  self.failure is None
}

///|
/// Return Completed or Error for current experiment.
pub fn ExperimentResult::status(self : ExperimentResult) -> ExecutionStatus {
  if self.is_completed() {
    Completed
  } else {
    Error
  }
}

///|
/// Return current experiment's immutable named output collection.
pub fn ExperimentResult::data(self : ExperimentResult) -> ResultData {
  self.outputs
}

///|
pub fn ExperimentResult::failed(
  program : @circuit.Program,
  error : @error.QError,
) -> ExperimentResult {
  {
    program_name: program.name(),
    shape: program.shape(),
    outputs: ResultData::new(),
    failure: Some(error),
  }
}

///|
pub fn ExperimentResult::error(self : ExperimentResult) -> @error.QError? {
  self.failure
}
