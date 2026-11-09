///|
/// Return the product of the dimensions, with a check before each multiply.
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
