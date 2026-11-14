///|
/// One execution's result.
struct ExperimentResult {
  /// Display name of the submitted program.
  program_name : String
  /// Ordered input dimensions.
  shape : Array[UInt32]
  /// Explicitly saved values from a successful experiment.
  outputs : @result_data.ResultData
  /// Error cause when current experiment failed.
  failure : @circuit.QuantumError?
}

///|
/// Record a successful execution of this program with its requested outputs.
pub fn ExperimentResult::completed(
  program : @circuit.Program,
  data : @result_data.ResultData,
) -> ExperimentResult {
  {
    program_name: program.name(),
    shape: program.dimensions(),
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
pub fn ExperimentResult::dimensions(self : ExperimentResult) -> Array[UInt32] {
  self.shape.copy()
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
pub fn ExperimentResult::data(
  self : ExperimentResult,
) -> @result_data.ResultData {
  self.outputs
}
