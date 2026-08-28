///|
fn array_intrinsic_source(declarations : String) -> String {
  "module Main\n\{declarations}"
}

///|
test "Array is a built-in unary type constructor" {
  let outcome = check_source(
    array_intrinsic_source(
      (
        #|pub struct Storage[T] {
        #|  values : Array[T]
        #|}
        #|
        #|pub fn empty(values : Array[I64]) -> Array[I64] { values }
      ),
    ),
  )
  assert_true(outcome is Succeeded(_))
}

///|
test "Array kind errors use ordinary type diagnostics" {
  let cases = [
    (
      #|pub struct MissingArgument {
      #|  values : Array
      #|}
    ),
    (
      #|pub struct EffectArgument {
      #|  values : Array[{}]
      #|}
    ),
  ]
  for declaration in cases {
    guard check_source(array_intrinsic_source(declaration)) is Failed(failure) else {
      fail("ill-kinded Array type unexpectedly succeeded")
    }
    assert_false(failure.diagnostics().is_empty())
  }
}

///|
test "Array intrinsics accept their canonical polymorphic schemes" {
  let outcome = check_source(
    array_intrinsic_source(
      (
        #|pub let array_empty : [Element]() -> Array[Element] = builtin("%array_empty")
        #|pub let array_make : [Element](I64, Element) -> Array[Element] = builtin("%array_make")
        #|pub let array_length : [Element](Array[Element]) -> I64 = builtin("%array_length")
        #|pub let array_get : [Element](Array[Element], I64) -> Element = builtin("%array_get")
        #|pub let array_set : [Element](Array[Element], I64, Element) -> Array[Element] = builtin("%array_set")
      ),
    ),
  )
  assert_true(outcome is Succeeded(_))
}

///|
test "Array intrinsic comparison is alpha-aware and directionally widens effects" {
  let outcome = check_source(
    array_intrinsic_source(
      (
        #|pub let empty_with_io : [Value]() -> Array[Value] ! Io = builtin("%array_empty")
        #|pub let get : [Result](Array[Result], I64) -> Result = builtin("%array_get")
      ),
    ),
  )
  assert_true(outcome is Succeeded(_))
}

///|
test "Array intrinsic rejects an incompatible polymorphic scheme" {
  guard check_source(
      array_intrinsic_source(
        (
          #|pub let array_get : [Element](Array[Element], I64) -> I64 = builtin("%array_get")
        ),
      ),
    )
    is Failed(failure) else {
    fail("incompatible Array intrinsic scheme unexpectedly succeeded")
  }
  assert_eq(failure.diagnostics().map(diagnostic => diagnostic.code), [
    Some("E3027"),
  ])
}

///|
test "Array types and builtin contracts roundtrip through module artifacts" {
  guard compile_modules({
      root: {
        source_id: "main",
        text: array_intrinsic_source(
          (
            #|pub let array_empty : [Element]() -> Array[Element] = builtin("%array_empty")
            #|pub fn preserve(values : Array[I64]) -> Array[I64] { values }
          ),
        ),
      },
      libraries: [],
    })
    is Succeeded(modules, _) else {
    fail("Array module did not compile")
  }
  assert_true(link_modules(modules) is Succeeded(_))
  let artifact = modules.artifact()
  guard artifact.modules is [module_] else {
    fail("expected one compiled module")
  }
  let interface_bytes = @artifact.module_interface_artifact_to_binary(
    module_.interface,
  )
  let object_bytes = @artifact.module_object_artifact_to_binary(module_.object)
  assert_eq(
    @artifact.parse_module_interface_artifact_binary(interface_bytes),
    Ok(module_.interface),
  )
  assert_eq(
    @artifact.parse_module_object_artifact_binary(object_bytes),
    Ok(module_.object),
  )
}

///|
test "exported Array intrinsics remain first-class across a module boundary" {
  guard compile_modules({
      root: {
        source_id: "main",
        text: (
          #|module Main
          #|import ArrayLibrary.{ array_empty }
          #|
          #|let make_empty : () -> Array[I64] = array_empty[I64]
          #|
          #|pub fn answer() -> Array[I64] { make_empty() }
        ),
      },
      libraries: [
        {
          source_id: "array-library",
          text: (
            #|module ArrayLibrary
            #|pub let array_empty : [Element]() -> Array[Element] = builtin("%array_empty")
          ),
        },
      ],
    })
    is Succeeded(modules, _) else {
    fail("exported first-class Array intrinsic did not compile")
  }
  assert_true(link_modules(modules) is Succeeded(_))
}
