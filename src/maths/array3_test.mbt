///|
test "Array3 shape and element access" {
  let values = @maths.Array3::make(2, 3, 4, 7)
  assert_eq(values.shape(), (2, 3, 4))
  assert_eq(values.length(), 24)
  assert_eq(values.get(0, 0, 0), Some(7))
  assert_true(values.set(1, 2, 3, 9))
  assert_eq(values.get(1, 2, 3), Some(9))
  assert_eq(values.get(0, 2, 3), Some(7))

  for
    (i, j, k) in [
      (-1, 0, 0),
      (0, -1, 0),
      (0, 0, -1),
      (2, 0, 0),
      (0, 3, 0),
      (0, 0, 4),
    ] {
    assert_eq(values.get(i, j, k), None)
    assert_false(values.set(i, j, k, 99))
  }
  assert_eq(values.get(1, 0, 0), Some(7))
}

///|
test "Array3 initialization and flat export follow row order" {
  let values = @maths.Array3::makei(2, 2, 3, fn(i, j, k) {
    i * 100 + j * 10 + k
  })

  assert_eq(values.get(1, 1, 2), Some(112))
  assert_eq(values.to_array(), [
    0, 1, 2, 10, 11, 12, 100, 101, 102, 110, 111, 112,
  ])
}

///|
test "Array3 copies and exported arrays have independent storage" {
  let original = @maths.Array3::make(1, 1, 2, 0)
  let copy = original.copy()
  let exported = original.to_array()

  assert_true(copy.set(0, 0, 0, 1))
  exported[1] = 2
  assert_eq(original.to_array(), [0, 0])
  assert_true(original.set(0, 0, 1, 3))
  assert_eq(copy.to_array(), [1, 0])
  assert_eq(exported, [0, 2])
}

///|
test "Array3 allows empty axes without invoking the initializer" {
  for (a, b, c) in [(0, 2, 3), (2, 0, 3), (2, 3, 0)] {
    let mut calls = 0
    let values = @maths.Array3::makei(a, b, c, fn(_, _, _) {
      calls += 1
      1
    })

    assert_eq(values.shape(), (a, b, c))
    assert_eq(values.length(), 0)
    assert_eq(values.to_array(), [])
    assert_eq(values.get(0, 0, 0), None)
    assert_false(values.set(0, 0, 0, 1))
    assert_eq(calls, 0)
  }
}
