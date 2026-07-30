///|
test "compiled aliases retain canonical interface and object identities" {
  let result = compile_modules_for_test(
    (
      #|module Main
      #|import Types as T
      #|pub fn echo(value : T.Item) -> T.Item { value }
    ),
    [
      (
        #|module Types
        #|pub struct Item {
        #|  value : I64
        #|}
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard @module_compile.find_compiled_module(modules.modules, "Main")
    is Some(main) else {
    abort("expected Main module")
  }
  debug_inspect(
    main.interface.type_references.map(fn(reference) {
      (reference.module_path, reference.name)
    }),
    content=(
      #|[("Types", "Item")]
    ),
  )
  debug_inspect(
    main.object.imports.map(fn(import_) {
      (import_.module_path_text, import_.reference, import_.name)
    }),
    content=(
      #|[
      #|  ("Types", Type({ index: 0 }), "Item"),
      #|  ("Types", DataConstructor({ index: 0 }), "Item"),
      #|  ("Types", FieldSelector({ index: 0 }), "Item.value"),
      #|]
    ),
  )
}

///|
test "tuple sugar compiles through an aliased canonical provider" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import Basic.Data.Tuple as Pair
      #|pub fn make() -> (I64, Bool) { (1, true) }
    ),
    [
      (
        #|module Basic.Data.Tuple
        #|pub enum Tuple[A, B] {
        #|  tuple(A, B)
        #|}
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="make",
  )
}

///|
test "list sugar compiles through an aliased canonical provider" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import Basic.Data.List as Seq
      #|pub fn make() -> Seq.List[I64] { [1, 2] }
    ),
    [
      (
        #|module Basic.Data.List
        #|pub enum List[T] {
        #|  empty()
        #|  cons(T, List[T])
        #|}
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="make",
  )
}
