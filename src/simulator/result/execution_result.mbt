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
/// Return a copy of the experiment list.
pub fn ExecutionResult::results(
  self : ExecutionResult,
) -> Array[ExperimentResult] {
  self.experiments.copy()
}

///|
pub extend ExecutionStatus with Eq::{equal, not_equal}

///|
pub extend ExecutionStatus with Debug::{to_repr}

///|
pub extend ResultError with Debug::{to_repr}
