///|
/// An immutable unitary effect.
struct Gate {
  label : String
  shape : Array[UInt32]
  /// Immutable numerical kernel, shared by derived values when possible.
  kernel_value : &UnitaryKernel
  size : Int32
}

///|
pub fn Gate::name(self : Gate) -> String {
  self.label
}

///|
pub fn Gate::dimensions(self : Gate) -> Array[UInt32] {
  self.shape.copy()
}

///|
pub fn Gate::arity(self : Gate) -> Int32 {
  self.shape.length()
}

///|
pub fn Gate::dimension(self : Gate) -> Int32 {
  self.size
}

///|
pub impl Debug for Gate with fn to_repr(self) {
  Debug::to_repr((self.label, self.shape))
}

///|
pub extend Gate with Debug::{to_repr}
