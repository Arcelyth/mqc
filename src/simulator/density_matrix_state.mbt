///|
pub impl SimulationState for @states.DensityMatrixState with fn dim(self) -> Array[
  UInt32,
] {
  self.dim()
}

///|
pub impl SimulationState for @states.DensityMatrixState with fn apply(
  self,
  instruction,
) -> Unit raise {
  self.apply(instruction)
}

///|
pub impl SimulationState for @states.DensityMatrixState with fn copy(self) -> @states.DensityMatrixState {
  self.copy()
}

///|
pub impl SimulationState for @states.DensityMatrixState with fn records(self) -> @maths.Array3[
  Int32,
] {
  self.records()
}

///|
pub impl SimulationState for @states.DensityMatrixState with fn validate(self) -> Unit raise {
  self.validate()
}
