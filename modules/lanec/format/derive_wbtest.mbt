///|
test "format derive expressions and preserve delimiter comments" {
  assert_format(
    (
      #|module Test
      #|pub let point_equal : Equal[Point] = derive // prefix
      #|[
      #|  // capability
      #|  Equal,
      #|  // target
      #|  Point,
      #|](
      #|  // explicit deriver
      #|  deriver=derive_equal,
      #|)
    ),
    (
      #|module Test
      #|
      #|pub let point_equal : Equal[Point] = derive // prefix
      #|[
      #|  // capability
      #|  Equal,
      #|  // target
      #|  Point
      #|](
      #|  // explicit deriver
      #|  deriver=derive_equal
      #|)
      #|
    ),
  )
}
