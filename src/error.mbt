///|
/// A common error type.
#alias(QuantumError)
#derive(Debug)
pub(all) suberror QError {
  Circuit(@circuit.CircuitError)
  Gate(@gates.GateError)
  Noise(@noise.NoiseError)
  Shape(@simulator.ShapeError)
  State(@simulator.StateError)
  Simulator(@simulator.SimulatorError)
  Result(@simulator.ResultError)
  Other(Error)
}

///|
pub fn QError::from_error(error : Error) -> QError {
  match error {
    QError::_ as cause => cause
    @circuit.CircuitError::_ as cause => Circuit(cause)
    @gates.GateError::_ as cause => Gate(cause)
    @noise.NoiseError::_ as cause => Noise(cause)
    @simulator.ShapeError::_ as cause => Shape(cause)
    @simulator.StateError::_ as cause => State(cause)
    @simulator.SimulatorError::_ as cause => Simulator(cause)
    @simulator.ResultError::_ as cause => Result(cause)
    _ => Other(error)
  }
}

///|
pub extend QError with Debug::{to_repr}
