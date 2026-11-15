///|
test "Complex constructors and arithmetic" {
  let a = @maths.Complex::new(2.0, 3.0)
  let b = @maths.Complex::new(4.0, -5.0)

  assert_eq(@maths.Complex::real(2.0), @maths.Complex::new(2.0, 0.0))
  assert_eq(a + b, @maths.Complex::new(6.0, -2.0))
  assert_eq(a - b, @maths.Complex::new(-2.0, 8.0))
  assert_eq(a * b, @maths.Complex::new(23.0, 2.0))
  assert_eq(-a, @maths.Complex::new(-2.0, -3.0))
}

///|
test "Complex conjugation, magnitude, and scaling" {
  let value = @maths.Complex::new(3.0, 4.0)

  assert_eq(value.conjugate(), @maths.Complex::new(3.0, -4.0))
  assert_eq(value.conjugate().conjugate(), value)
  assert_eq(value.norm_squared(), 25.0)
  assert_eq(value * value.conjugate(), @maths.Complex::real(25.0))
  assert_eq(value.scale(2.0), @maths.Complex::new(6.0, 8.0))
  assert_eq(value, @maths.Complex::new(3.0, 4.0))
}

///|
test "Complex phase uses radians and has unit magnitude" {
  assert_eq(@maths.Complex::phase(0.0), @maths.Complex::real(1.0))
  let value = @maths.Complex::phase(1.5707963267948966)

  assert_true(value.re.abs() < 1.0e-12)
  assert_true((value.im - 1.0).abs() < 1.0e-12)
  assert_true((value.norm_squared() - 1.0).abs() < 1.0e-12)
}

///|
test "Complex finiteness checks both components" {
  assert_true(@maths.Complex::new(1.0e300, -1.0e300).is_finite())
  let infinity = 1.0 / 0.0
  let nan = 0.0 / 0.0
  for
    value in [
      @maths.Complex::new(infinity, 0.0),
      @maths.Complex::new(0.0, -infinity),
      @maths.Complex::new(nan, 0.0),
      @maths.Complex::new(0.0, nan),
    ] {
    assert_false(value.is_finite())
  }
}
