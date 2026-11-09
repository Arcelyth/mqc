///|
/// Completion of one experiment or a whole batch.
#derive(Eq, Debug)
pub(all) enum ExecutionStatus {
  /// No experiments were submitted.
  Empty
  /// Every experiment completed.
  Completed
  /// At least one experiment completed and at least one failed.
  PartialCompleted
  /// Every experiment failed.
  Error
}

///|
#derive(Debug)
pub suberror ResultError {
  MissingExperiment(Int32)
  ExperimentFailed(Int32)
  MissingData(String)
  WrongDataType(String, String)
}

///|
pub(open) trait ResultValue {
  /// A display name for current representation.
  fn type_name(Self) -> String
  /// Try to offer pure state.
  fn try_statevector(Self) -> StateVector? = _
}

///|
impl ResultValue with fn try_statevector(_self) -> StateVector? {
  None
}

///|
/// Named output data from one experiment. Only requested outputs are stored.
struct ResultData {
  values : @hashmap.HashMap[String, &ResultValue]
}

///|
pub fn ResultData::new() -> ResultData {
  { values: @hashmap.HashMap::new(), }
}

///|
/// One execution's result.
struct ExperimentResult {
  /// Display name of the submitted program.
  program_name : String
  /// Ordered input dimensions.
  shape : Array[UInt32]
  /// Explicitly saved values from a successful experiment.
  outputs : ResultData
  /// Error cause when current experiment failed.
  failure : @circuit.QuantumError?
}

///|
/// Record a successful execution of this program with its requested outputs.
pub fn ExperimentResult::completed(
  program : @circuit.Program,
  data : ResultData,
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
/// Return a copy of the input program's ordered wire dimensions.
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
pub fn ExperimentResult::data(self : ExperimentResult) -> ResultData {
  self.outputs
}

///|
/// A backend's result for one or more experiments, in submission order.
struct ExecutionResult {
  /// Display name of the backend that executed the batch.
  backend : String
  experiments : Array[ExperimentResult]
  status : ExecutionStatus
}

///|
/// Build a result and derive its status from the experiments. Copy the input array.
pub fn ExecutionResult::new(
  backend_name : String,
  experiments : Array[ExperimentResult],
) -> ExecutionResult {
  let mut completed = 0
  for experiment in experiments {
    if experiment.is_completed() {
      completed += 1
    }
  }
  let status = if experiments.is_empty() {
    Empty
  } else if completed == experiments.length() {
    Completed
  } else if completed == 0 {
    Error
  } else {
    PartialCompleted
  }
  { backend: backend_name, experiments: experiments.copy(), status, }
}

///|
/// Return the backend's display name.
pub fn ExecutionResult::backend_name(self : ExecutionResult) -> String {
  self.backend
}

///|
/// Return the combined batch status.
pub fn ExecutionResult::status(self : ExecutionResult) -> ExecutionStatus {
  self.status
}

///|
/// Return true only when every submitted experiment completed.
pub fn ExecutionResult::is_completed(self : ExecutionResult) -> Bool {
  self.status == Completed
}

///|
/// Return the experiment count.
pub fn ExecutionResult::length(self : ExecutionResult) -> Int32 {
  self.experiments.length()
}

///|
/// Return a copy of the experiment list.
pub fn ExecutionResult::results(
  self : ExecutionResult,
) -> Array[ExperimentResult] {
  self.experiments.copy()
}

///|
/// Read an experiment, including its failure status. Reject an out-of-range index.
pub fn ExecutionResult::experiment(
  self : ExecutionResult,
  index : Int32,
) -> ExperimentResult raise ResultError {
  if index < 0 || index >= self.experiments.length() {
    raise MissingExperiment(index)
  }
  self.experiments[index]
}

///|
pub extend ExecutionStatus with Eq::{equal, not_equal}

///|
pub extend ExecutionStatus with Debug::{to_repr}

///|
pub extend ResultError with Debug::{to_repr}
