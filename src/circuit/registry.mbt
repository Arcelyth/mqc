///|
/// Assign each identifier a stable index in registration order.
pub struct Registry[I] {
  priv items : Array[I]
  priv indices : @hashmap.HashMap[I, Int32]
}

///|
/// Register distinct identifiers in the supplied order.
pub fn[I : Id] Registry::new(ids : Array[I]) -> Registry[I] raise CircuitError {
  let items = ids.copy()
  let mut indices = @hashmap.empty()
  for i, qid in items {
    if indices.contains(qid) {
      raise DuplicateQid(i)
    }
    indices = indices.insert(qid, i)
  }
  { items, indices, }
}

///|
/// Return a registry with a new identifier at the end. Reject duplicates.
pub fn[I : Id] Registry::add(
  self : Registry[I],
  qid : I,
) -> Registry[I] raise CircuitError {
  let index = self.len()
  if self.indices.contains(qid) {
    raise DuplicateQid(index)
  }
  let items = self.items.copy()
  items.push(qid)
  { items, indices: self.indices.insert(qid, index), }
}

///|
pub fn[I] Registry::len(self : Registry[I]) -> Int32 {
  self.items.length()
}

///|
pub fn[I] Registry::is_empty(self : Registry[I]) -> Bool {
  self.items.is_empty()
}

///|
/// Keep existing indices and append new wires in the other registry's order.
/// Wires shared by both registries must agree on their dimension.
pub fn[I : Qid] Registry::merge(
  self : Registry[I],
  other : Registry[I],
) -> Registry[I] raise CircuitError {
  self.with_targets(Iter::singleton(other.items))
}

///|
fn[I : Id] Registry::union(
  self : Registry[I],
  other : Registry[I],
) -> Registry[I] {
  guard !self.is_empty() else { return other }
  let mut items = self.items
  let mut indices = self.indices
  for id in other.items {
    if !indices.contains(id) {
      if items.length() == self.items.length() {
        items = items.copy()
      }
      indices = indices.insert(id, items.length())
      items.push(id)
    }
  }
  { items, indices, }
}

///|
/// Look up a wire's index.
pub fn[I : Id] Registry::get(self : Registry[I], qid : I) -> Int32? {
  self.indices.get(qid)
}

///|
/// Look up the wire at an index. Return `None` outside the registry.
pub fn[I] Registry::at(self : Registry[I], index : Int32) -> I? {
  self.items.get(index)
}

///|
/// Return the wire dimension at a valid index.
pub fn[I : Qid] Registry::dim_at(self : Registry[I], index : Int32) -> UInt32 {
  self.items[index].dim()
}

///|
/// Return the wire dimensions in basis order.
pub fn[I : Qid] Registry::dims(self : Registry[I]) -> Array[UInt32] {
  self.items.map(qid => qid.dim())
}

///|
fn[I : Id] Registry::index(self : Registry[I], qid : I) -> Int32 {
  self.indices[qid]
}

///|
/// Register each group in order. Error positions are local to each group.
fn[I : Qid] Registry::with_targets(
  self : Registry[I],
  groups : Iter[Array[I]],
) -> Registry[I] raise CircuitError {
  let mut items = self.items
  let mut indices = self.indices
  let original_count = items.length()
  for group in groups {
    for position, qid in group {
      match indices.get(qid) {
        Some(index) => {
          let expected = items[index].dim()
          let actual = qid.dim()
          if expected != actual {
            raise DimensionMismatch(position, expected, actual)
          }
        }
        None => {
          // Copy on the first addition. Other circuits can share this array.
          if items.length() == original_count {
            items = items.copy()
          }
          indices = indices.insert(qid, items.length())
          items.push(qid)
        }
      }
    }
  }
  if items.length() == original_count {
    self
  } else {
    { items, indices, }
  }
}
