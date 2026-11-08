///|
#derive(Debug)
pub(all) suberror QuantumError {
  /// A wire dimension is below two; carries that dimension.
  InvalidDimension(UInt32)
  /// A size budget is invalid or exceeded; carries the reported limit.
  SizeLimit(Int32)
  /// Gate data or a gate capability violates its contract; carries the reason.
  InvalidGate(String)
  /// A logical ID repeats; carries its position in the supplied array.
  DuplicateQid(Int32)
  /// Target count mismatch; carries expected and actual wire counts.
  TargetCount(Int32, Int32)
  /// Wire shape mismatch; carries target position, expected dimension, and actual
  /// dimension.
  DimensionMismatch(Int32, UInt32, UInt32)
}

///|
/// Return the product of the dimensions, with a check before each multiply.
/// An empty shape has one basis state.
pub fn space_size(
  shape : Array[UInt32],
  max_size~ : Int32 = 2147483647,
) -> Int32 raise QuantumError {
  if max_size < 1 {
    raise SizeLimit(max_size)
  }
  let mut size = 1
  for dim in shape {
    if dim < 2U {
      raise InvalidDimension(dim)
    }
    if dim > (max_size / size).reinterpret_as_uint() {
      raise SizeLimit(max_size)
    }
    size = size * dim.reinterpret_as_int()
  }
  size
}

///|
pub extend QuantumError with Debug::{to_repr}
