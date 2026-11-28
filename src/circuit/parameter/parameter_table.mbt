///|
#derive(Eq, Hash)
priv enum ParameterUse {
  /// A zero-based index into the circuit's top-level instructions.
  Instruction(Int32)
  /// A use in the circuit's global phase expression.
  GlobalPhase
}

///|
/// Tracks one free parameter in a circuit.
priv struct ParameterInfo {
  /// The symbol returned by parameter lookup.
  param : Parameter
  /// The locations where the parameter appears.
  uses : @hashset.HashSet[ParameterUse]
}

///|
/// Index parameters by ID and name.
struct ParameterTable {
  by_id : @hashmap.HashMap[ParameterId, ParameterInfo]
  by_name : @hashmap.HashMap[String, ParameterId]
}

///|
pub fn ParameterTable::empty() -> ParameterTable {
  { by_id: @hashmap.empty(), by_name: @hashmap.empty(), }
}

///|
/// Record the parameters used at one instruction position.
pub fn ParameterTable::track(
  self : ParameterTable,
  parameters : Array[Parameter],
  position : Int32,
) -> ParameterTable raise ParameterError {
  self.track_use(parameters, Instruction(position))
}

///|
/// Record the parameters used by the circuit's global phase.
pub fn ParameterTable::track_phase(
  self : ParameterTable,
  parameters : Array[Parameter],
) -> ParameterTable raise ParameterError {
  self.track_use(parameters, GlobalPhase)
}

///|
fn ParameterTable::track_use(
  self : ParameterTable,
  parameters : Array[Parameter],
  usage : ParameterUse,
) -> ParameterTable raise ParameterError {
  let mut table = self
  for parameter in parameters {
    table = table.track_uses(parameter, Iter::singleton(usage))
  }
  table
}

///|
fn ParameterTable::track_uses(
  self : ParameterTable,
  parameter : Parameter,
  usages : Iter[ParameterUse],
) -> ParameterTable raise ParameterError {
  let id = parameter.id()
  if self.by_id.get(id) is Some(info) {
    let mut uses = info.uses
    for usage in usages {
      uses = uses.insert(usage)
    }
    return { ..self, by_id: self.by_id.insert(id, { ..info, uses, }), }
  }
  let name = parameter.name()
  if self.by_name.contains(name) {
    raise NameConflict(name)
  }
  let info = { param: parameter, uses: @hashset.from_iter(usages), }
  {
    by_id: self.by_id.insert(id, info),
    by_name: self.by_name.insert(name, id),
  }
}

///|
/// Remove the uses at one position. Drop parameters with no remaining uses.
pub fn ParameterTable::untrack(
  self : ParameterTable,
  parameters : Array[Parameter],
  position : Int32,
) -> ParameterTable {
  self.untrack_use(parameters, Instruction(position))
}

///|
/// Remove the uses from the circuit's global phase.
pub fn ParameterTable::untrack_phase(
  self : ParameterTable,
  parameters : Array[Parameter],
) -> ParameterTable {
  self.untrack_use(parameters, GlobalPhase)
}

///|
fn ParameterTable::untrack_use(
  self : ParameterTable,
  parameters : Array[Parameter],
  usage : ParameterUse,
) -> ParameterTable {
  let mut by_id = self.by_id
  let mut by_name = self.by_name
  for parameter in parameters {
    let id = parameter.id()
    if by_id.get(id) is Some(info) {
      let remaining = info.uses.remove(usage)
      if remaining.is_empty() {
        by_id = by_id.remove(id)
        by_name = by_name.remove(info.param.name())
      } else {
        by_id = by_id.insert(id, { ..info, uses: remaining, })
      }
    }
  }
  { by_id, by_name, }
}

///|
/// Combine the tables, shifting the other table's positions by offset.
pub fn ParameterTable::concat(
  self : ParameterTable,
  other : ParameterTable,
  offset : Int32,
) -> ParameterTable raise ParameterError {
  let mut table = self
  for info in other.by_id.values() {
    let uses = info.uses
      .iter()
      .map(usage => {
        match usage {
          Instruction(position) => Instruction(position + offset)
          GlobalPhase => GlobalPhase
        }
      })
    table = table.track_uses(info.param, uses)
  }
  table
}

///|
/// Find a parameter by its name.
pub fn ParameterTable::get_by_name(
  self : ParameterTable,
  name : String,
) -> Parameter? {
  self.by_name.get(name).bind(id => self.by_id.get(id)).map(info => info.param)
}

///|
/// Return indexed parameters in name order.
pub fn ParameterTable::parameters(self : ParameterTable) -> Array[Parameter] {
  let parameters = self.by_id.values().map(info => info.param).collect()
  parameters.sort_by((left, right) => left.name().lexical_compare(right.name()))
  parameters
}

///|
/// Return the distinct use positions in instruction order.
/// In strict mode, each input parameter must be present.
pub fn ParameterTable::positions(
  self : ParameterTable,
  parameters : Iter[Parameter],
  strict : Bool,
) -> Array[Int32] raise ParameterError {
  let mut uses = @hashset.empty()
  for parameter in parameters {
    match self.by_id.get(parameter.id()) {
      Some(info) => uses = uses.union(info.uses)
      None if strict =>
        raise InvalidParameter(
          "parameter is absent from the circuit: " + parameter.name(),
        )
      None => ()
    }
  }
  let positions = uses
    .iter()
    .filter_map(usage => {
      match usage {
        Instruction(position) => Some(position)
        GlobalPhase => None
      }
    })
    .collect()
  positions.sort()
  positions
}
