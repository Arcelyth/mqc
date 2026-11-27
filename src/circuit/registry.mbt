///|
/// Assign each wire a stable index in basis order.
pub struct Registry[Q] {
  priv items : Array[Q]
  priv indices : @hashmap.HashMap[Q, Int32]
}

///|
/// Register distinct wires in the supplied order.
pub fn[Q : Qid] Registry::new(
  qids : Array[Q],
) -> Registry[Q] raise @error.QError {
  let items = qids.copy()
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
/// Return a registry with a new wire at the end. Reject duplicate IDs.
pub fn[Q : Qid] Registry::add(
  self : Registry[Q],
  qid : Q,
) -> Registry[Q] raise @error.QError {
  if self.get(qid) is Some(_) {
    raise DuplicateQid(self.len())
  }
  self.with_targets(Iter::singleton([qid]))
}

///|
pub fn[Q] Registry::len(self : Registry[Q]) -> Int32 {
  self.items.length()
}

///|
pub fn[Q] Registry::is_empty(self : Registry[Q]) -> Bool {
  self.items.is_empty()
}

///|
/// Keep existing indices and append new wires in the other registry's order.
/// Wires shared by both registries must agree on their dimension.
pub fn[Q : Qid] Registry::merge(
  self : Registry[Q],
  other : Registry[Q],
) -> Registry[Q] raise @error.QError {
  self.with_targets(Iter::singleton(other.items))
}

///|
/// Look up a wire's index.
pub fn[Q : Qid] Registry::get(self : Registry[Q], qid : Q) -> Int32? {
  self.indices.get(qid)
}

///|
/// Look up the wire at an index. Return `None` outside the registry.
pub fn[Q] Registry::at(self : Registry[Q], index : Int32) -> Q? {
  self.items.get(index)
}

///|
/// Return the wire dimension at a valid index.
pub fn[Q : Qid] Registry::dim_at(self : Registry[Q], index : Int32) -> UInt32 {
  self.items[index].dim()
}

///|
/// Return the wire dimensions in basis order.
pub fn[Q : Qid] Registry::dims(self : Registry[Q]) -> Array[UInt32] {
  self.items.map(qid => qid.dim())
}

///|
fn[Q : Qid] Registry::index(self : Registry[Q], qid : Q) -> Int32 {
  self.indices[qid]
}

///|
/// Register each group in order. Error positions are local to each group.
fn[Q : Qid] Registry::with_targets(
  self : Registry[Q],
  groups : Iter[Array[Q]],
) -> Registry[Q] raise @error.QError {
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
