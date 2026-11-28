///|
test "parameter identity is independent of the name and assignment is simultaneous" {
  let a = @parameter.Parameter::new("angle")
  let b = @parameter.Parameter::new("angle")
  assert_true(a != b)
  let restored = @parameter.Parameter::new("restored angle", id=a.id())
  assert_eq(restored, a)
  let expr = a.expr() + b.expr()
  let assigned = expr.assign(
    Map([(restored, b.expr()), (b, @parameter.ParamExpr::constant(2.0))]),
  )
  assert_eq(assigned.parameters(), [b])
  let bound = assigned.assign(Map([(b, @parameter.ParamExpr::constant(3.0))]))
  assert_eq(bound.value(), 5.0)
}
