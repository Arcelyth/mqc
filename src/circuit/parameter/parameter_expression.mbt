///|
priv enum ParamOp {
  Plus
  Minus
  Times
  Divide
}

///|
enum ParamExpr {
  Constant(Double)
  Symbol(Parameter)
  Binary(ParamOp, ParamExpr, ParamExpr)
}

///|
pub fn ParamExpr::constant(value : Double) -> ParamExpr {
  Constant(value)
}

///|
pub fn ParamExpr::constant_value(self : ParamExpr) -> Double? {
  match self {
    Constant(value) => Some(value)
    _ => None
  }
}

///|
pub impl Add for ParamExpr with fn add(self, other) {
  Binary(Plus, self, other)
}

///|
pub impl Sub for ParamExpr with fn sub(self, other) {
  Binary(Minus, self, other)
}

///|
pub impl Mul for ParamExpr with fn mul(self, other) {
  Binary(Times, self, other)
}

///|
pub impl Div for ParamExpr with fn div(self, other) {
  Binary(Divide, self, other)
}

///|
pub impl Neg for ParamExpr with fn neg(self) {
  Binary(Minus, Constant(0.0), self)
}

///|
fn ParamExpr::collect_symbols(
  self : ParamExpr,
  symbols : Map[Parameter, Unit],
) -> Unit {
  match self {
    Constant(_) => ()
    Symbol(parameter) => symbols[parameter] = ()
    Binary(_, left, right) => {
      left.collect_symbols(symbols)
      right.collect_symbols(symbols)
    }
  }
}

///|
/// Return each parameter in the expression once.
pub fn ParamExpr::parameters(self : ParamExpr) -> Array[Parameter] {
  let symbols = Map([])
  self.collect_symbols(symbols)
  symbols.keys().collect()
}

///|
/// Substitute parameters in the expression using the supplied bindings.
///
/// Each parameter is replaced at most once. Replacement expressions are
/// not recursively substituted using the same bindings.
///
/// For example, given `theta + phi` and bindings
/// `{theta: phi, phi: 1}`, the result is `phi + 1`, not `2`.
///
/// Constant expressions are folded after substitution.
///
/// Raises [ParameterError] if the resulting expression contains an
/// invalid constant, such as NaN or infinity.
pub fn ParamExpr::assign(
  self : ParamExpr,
  bindings : Map[Parameter, ParamExpr],
) -> ParamExpr raise ParameterError {
  match self {
    Constant(value) => checked_constant(value)
    Symbol(parameter) =>
      match bindings.get(parameter) {
        Some(replacement) => replacement.fold_constants()
        None => self
      }
    Binary(operator, left, right) =>
      fold_binary(operator, left.assign(bindings), right.assign(bindings))
  }
}

///|
fn ParamExpr::fold_constants(
  self : ParamExpr,
) -> ParamExpr raise ParameterError {
  match self {
    Constant(value) => checked_constant(value)
    Symbol(_) => self
    Binary(operator, left, right) =>
      fold_binary(operator, left.fold_constants(), right.fold_constants())
  }
}

///|
fn checked_constant(value : Double) -> ParamExpr raise ParameterError {
  if value.is_nan() || value.is_inf() {
    raise InvalidParameter("parameter values must be finite")
  }
  Constant(value)
}

///|
fn fold_binary(
  operator : ParamOp,
  left : ParamExpr,
  right : ParamExpr,
) -> ParamExpr raise ParameterError {
  guard (left, right) is (Constant(a), Constant(b)) else {
    return Binary(operator, left, right)
  }
  let value = match operator {
    Plus => a + b
    Minus => a - b
    Times => a * b
    Divide => a / b
  }
  checked_constant(value)
}

///|
/// Evaluate an expression to a finite number.
/// Raises `ParameterError` for unbound parameters or non-finite values.
pub fn ParamExpr::value(self : ParamExpr) -> Double raise ParameterError {
  guard self.fold_constants() is Constant(value) else {
    raise InvalidParameter("parameter expression is unbound")
  }
  value
}
