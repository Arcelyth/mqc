///|
pub impl SimulationState for @states.StateVectorState with fn dim(self) -> Array[
  UInt32,
] {
  self.dim()
}

///|
pub impl SimulationState for @states.StateVectorState with fn apply(
  self,
  instruction,
) -> Unit raise {
  self.apply(instruction)
}

///|
pub impl SimulationState for @states.StateVectorState with fn copy(self) -> @states.StateVectorState {
  self.copy()
}

///|
pub impl SimulationState for @states.StateVectorState with fn records(self) -> @maths.Array3[
  Int32,
] {
  self.records()
}

///|
pub impl SimulationState for @states.StateVectorState with fn validate(self) -> Unit raise {
  self.validate()
}
