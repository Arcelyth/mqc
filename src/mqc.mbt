///|
pub using @circuit {
  trait Qid,
  trait Effect,
  trait Condition,
  trait NoiseModel,
  trait MeasurementRecord,
  type MeasurementCondition,
  trait LinearKernel,
  trait UnitaryKernel,
  type QubitId,
  type QuditId,
  type Gate,
  type Channel,
  type Operation,
  type ConditionalEffect,
  type Circuit,
  type Program,
  type Instruction,
  type IfElse,
  type ForLoop,
  type WhileLoop,
}

///|
pub using @error {
  type QError,
  /// Alias of QError.
  type QuantumError,
}

///|
pub using @maths {type Complex}

///|
pub using @simulator {
  type StateVector,
  type DensityMatrix,
  type DensityMatrixState,
  type DensityMatrixSimulator,
  trait ResultValue,
  type ExecutionResult,
  type ExperimentResult,
  type ExecutionStatus,
  type ResultData,
  type ResultError,
  type Simulator,
  trait SimulationState,
  type SimulationStateBase,
  type StepResult,
  type TrialResult,
  type StateVectorState,
  trait Sampler,
  type StateVectorSimulator,
  type SamplerResult,
}
