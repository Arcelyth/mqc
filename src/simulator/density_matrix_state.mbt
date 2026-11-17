///|
pub impl SimulationState for @result_data.DensityMatrixState with fn dim(self) -> Array[
  UInt32,
] {
  self.dim()
}

///|
pub impl SimulationState for @result_data.DensityMatrixState with fn apply(
  self,
  instruction,
) -> Unit raise @error.QError {
  self.apply(instruction)
}

///|
pub impl SimulationState for @result_data.DensityMatrixState with fn copy(self) -> @result_data.DensityMatrixState {
  self.copy()
}

///|
pub impl SimulationState for @result_data.DensityMatrixState with fn records(
  self,
) -> @maths.Array3[Int32] {
  self.records()
}

///|
pub impl SimulationState for @result_data.DensityMatrixState with fn validate(
  self,
) -> Unit raise @error.QError {
  self.validate()
}
