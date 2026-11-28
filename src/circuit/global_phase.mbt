///|
priv struct GlobalPhase {
  angle : ParamExpr
  gate : Gate?
}

///|
fn GlobalPhase::new(angle : ParamExpr) -> GlobalPhase {
  let gate = angle
    .constant_value()
    .map(value => Gate::{
      label: "global phase",
      shape: @internal.Shape::new([]),
      kernel_value: MonomialKernel::{
        columns: [0],
        phases: [@maths.Complex::phase(value)],
      },
    })
  { angle, gate, }
}

///|
fn[Q] GlobalPhase::instruction(angle : ParamExpr) -> Instruction[Q]? {
  guard angle.constant_value() != Some(0.0) else { return None }
  Some(Operation({ effect: GlobalPhase::new(angle), wires: [], }))
}

///|
impl Effect for GlobalPhase with fn name(_) {
  "global phase"
}

///|
impl Effect for GlobalPhase with fn dim(_) {
  []
}

///|
impl Effect for GlobalPhase with fn try_unitary(self) {
  self.gate
}

///|
impl Effect for GlobalPhase with fn try_adjoint(self) {
  let angle = (-self.angle).assign(Map([])) catch {
    error => raise CircuitError::Parameter(error)
  }
  Some(GlobalPhase::new(angle))
}

///|
impl Effect for GlobalPhase with fn parameter_symbols(self) {
  self.angle.parameters()
}

///|
impl Effect for GlobalPhase with fn assign_parameters(self, bindings) {
  GlobalPhase::new(self.angle.assign(bindings))
}
