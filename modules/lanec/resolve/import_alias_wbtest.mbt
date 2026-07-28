///|
priv struct ImportAliasFixture {
  registry : SymbolRegistry
  imported : @module_interface.ImportedEnvironment
  value : ValueSymbolId
  empty : VariantSymbolId
  tuple : VariantSymbolId
}

///|
fn import_alias_fixture() -> ImportAliasFixture {
  let registry = SymbolRegistry()
  let loc = @basic.SourceSpan::dummy()
  let value = registry.define_value("value", TopLevelValue, loc)
  let list = registry.define_type("List", Enum, 0, loc)
  let empty = registry.define_variant(list, "empty", 0, 0, loc)
  let cons = registry.define_variant(list, "cons", 1, 2, loc)
  let tuple_type = registry.define_type("Tuple", Enum, 0, loc)
  let tuple = registry.define_variant(tuple_type, "tuple", 0, 2, loc)
  let library = @module_interface.ModuleInterface::{
    module_path: "Lib",
    source_id: Some("file:///Lib.lane"),
    type_references: [],
    effect_references: [],
    types: [],
    effects: [],
    type_aliases: [],
    values: [
      {
        symbol: value,
        kind: Let,
        is_offered: false,
        name: "value",
        type_: Primitive(Int),
        parameters: None,
        loc,
      },
    ],
    optimization_hints: [],
  }
  let list_module = @module_interface.ModuleInterface::{
    module_path: "Basic.Data.List",
    source_id: Some("file:///List.lane"),
    type_references: [],
    effect_references: [],
    types: [
      Enum({
        symbol: list,
        name: "List",
        type_parameters: [],
        variants: [
          {
            symbol: empty,
            name: "empty",
            index: 0,
            type_parameters: [],
            payload: [],
            loc,
          },
          {
            symbol: cons,
            name: "cons",
            index: 1,
            type_parameters: [],
            payload: [Primitive(Int), Constructor(list)],
            loc,
          },
        ],
        loc,
      }),
    ],
    effects: [],
    type_aliases: [],
    values: [],
    optimization_hints: [],
  }
  let tuple_module = @module_interface.ModuleInterface::{
    module_path: "Basic.Data.Tuple",
    source_id: Some("file:///Tuple.lane"),
    type_references: [],
    effect_references: [],
    types: [
      Enum({
        symbol: tuple_type,
        name: "Tuple",
        type_parameters: [],
        variants: [
          {
            symbol: tuple,
            name: "tuple",
            index: 0,
            type_parameters: [],
            payload: [Primitive(Int), Primitive(Bool)],
            loc,
          },
        ],
        loc,
      }),
    ],
    effects: [],
    type_aliases: [],
    values: [],
    optimization_hints: [],
  }
  {
    registry,
    imported: { modules: [library, list_module, tuple_module] },
    value,
    empty,
    tuple,
  }
}

///|
fn resolve_import_alias_source(
  fixture : ImportAliasFixture,
  source : String,
) -> ResolveResult {
  let parsed = @parser.parse_string("module Test\n" + source)
  if !parsed.lexical_errors().is_empty() || !parsed.parse_errors().is_empty() {
    abort("expected import alias test source to parse")
  }
  guard parsed.syntax() is Some(file) else { abort("expected source file") }
  resolve_source_file_with_imports_result(
    file,
    fixture.registry,
    fixture.imported,
  )
}

///|
fn used_import_exposure_ids(source : ResolvedSourceFile) -> Array[Int] {
  let ids = []
  for use_ in source.import_uses {
    if !ids.contains(use_.exposure_id) {
      ids.push(use_.exposure_id)
    }
  }
  ids
}

///|
test "aliased qualified import replaces the canonical authored qualifier" {
  let fixture = import_alias_fixture()
  let aliased = resolve_import_alias_source(
    fixture,
    (
      #|import Lib as Short
      #|fn read() -> Int { Short.value }
    ),
  )
  debug_inspect(aliased.diagnostics, content="[]")
  guard aliased.source.declarations[0] is Function(function) else {
    abort("expected function")
  }
  assert_true(
    function.body is Block(result=Var(reference=Symbol(symbol), ..), ..) &&
    symbol == fixture.value,
  )

  let canonical = resolve_import_alias_source(
    import_alias_fixture(),
    (
      #|import Lib as Short
      #|fn read() -> Int { Lib.value }
    ),
  )
  inspect(
    @prettyprinter.render(
      canonical.diagnostics.map(fn(diagnostic) { diagnostic.kind }),
      width=100,
    ),
    content="[unresolved_value Lib]",
  )
}

///|
test "distinct aliases may bind the same imported module" {
  let fixture = import_alias_fixture()
  let result = resolve_import_alias_source(
    fixture,
    (
      #|import Lib as First
      #|import Lib as Second
      #|fn first() -> Int { First.value }
      #|fn second() -> Int { Second.value }
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
  assert_eq(used_import_exposure_ids(result.source), [0, 1])
}

///|
test "authored access marks only its local module binding" {
  let result = resolve_import_alias_source(
    import_alias_fixture(),
    (
      #|import Lib as First
      #|import Lib as Second
      #|fn read() -> Int { First.value }
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
  assert_eq(used_import_exposure_ids(result.source), [0])
}

///|
test "a local module binding name is unique" {
  let result = resolve_import_alias_source(
    import_alias_fixture(),
    (
      #|import Lib as Shared
      #|import Lib as Shared
    ),
  )
  inspect(
    @prettyprinter.render(
      result.diagnostics.map(fn(diagnostic) { diagnostic.kind }),
      width=100,
    ),
    content="[ambiguous_module_binding Shared]",
  )
}

///|
test "the current module name cannot be reused as an import binding" {
  let result = resolve_import_alias_source(
    import_alias_fixture(),
    "import Lib as Test",
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: AmbiguousModuleBinding(
      #|      name="Test",
      #|      existing_loc={
      #|        start_offset: 7,
      #|        end_offset: 11,
      #|        start_line: 1,
      #|        start_column: 8,
      #|        end_line: 1,
      #|        end_column: 12,
      #|      },
      #|    ),
      #|    loc: {
      #|      start_offset: 26,
      #|      end_offset: 30,
      #|      start_line: 2,
      #|      start_column: 15,
      #|      end_line: 2,
      #|      end_column: 19,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "tuple sugar resolves canonically through an aliased import" {
  let fixture = import_alias_fixture()
  let result = resolve_import_alias_source(
    fixture,
    (
      #|import Basic.Data.Tuple as Pair
      #|fn authored() -> Pair.Tuple { Pair.Tuple::tuple(1, true) }
      #|fn generated() -> (Int, Bool) { (1, true) }
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.source.declarations[0] is Function(authored) &&
    authored.body
    is Block(result=QualifiedVariant(reference=Symbol(authored_tuple), ..), ..) &&
    result.source.declarations[1] is Function(generated) &&
    generated.body
    is Block(result=QualifiedVariant(reference=Symbol(generated_tuple), ..), ..) else {
    abort("expected authored and generated tuple variants")
  }
  assert_eq(authored_tuple, fixture.tuple)
  assert_eq(generated_tuple, fixture.tuple)
}

///|
test "tuple sugar does not change authored module lookup" {
  let result = resolve_import_alias_source(
    import_alias_fixture(),
    (
      #|import Basic.Data.Tuple as Pair
      #|fn generated() -> (Int, Bool) { (1, true) }
      #|fn authored(value : Basic.Data.Tuple.Tuple) -> Unit { () }
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: UnresolvedType("Basic.Data.Tuple.Tuple"),
      #|    loc: {
      #|      start_offset: 108,
      #|      end_offset: 130,
      #|      start_line: 4,
      #|      start_column: 21,
      #|      end_line: 4,
      #|      end_column: 43,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "module aliases do not rewrite longer path prefixes" {
  let result = resolve_import_alias_source(
    import_alias_fixture(),
    (
      #|import Lib as Short
      #|fn read() -> Int { Short.Nested.value }
    ),
  )
  inspect(
    @prettyprinter.render(
      result.diagnostics.map(fn(diagnostic) { diagnostic.kind }),
      width=100,
    ),
    content="[unresolved_value Short.Nested.value]",
  )
}

///|
test "module aliases coexist with type names and retain value ambiguity" {
  let result = resolve_import_alias_source(
    import_alias_fixture(),
    (
      #|import Lib as Same
      #|struct Same {}
      #|fn typed(value : Same) -> Same { value }
      #|fn ambiguous(Same : Int) -> Int { Same.value }
    ),
  )
  inspect(
    @prettyprinter.render(
      result.diagnostics.map(fn(diagnostic) { diagnostic.kind }),
      width=100,
    ),
    content="[ambiguous_module_value Same.value]",
  )
}

///|
test "list sugar resolves canonically through aliased imports" {
  let fixture = import_alias_fixture()
  let result = resolve_import_alias_source(
    fixture,
    (
      #|import Basic.Data.List as First
      #|import Basic.Data.List as Second
      #|fn authored() -> First.List { First.List::empty() }
      #|fn generated() -> First.List { [] }
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.source.declarations[0] is Function(authored) &&
    authored.body
    is Block(result=QualifiedVariant(reference=Symbol(authored_empty), ..), ..) &&
    result.source.declarations[1] is Function(generated) &&
    generated.body
    is Block(result=QualifiedVariant(reference=Symbol(generated_empty), ..), ..) else {
    abort("expected authored and generated empty variants")
  }
  assert_eq(authored_empty, fixture.empty)
  assert_eq(generated_empty, fixture.empty)
  assert_eq(used_import_exposure_ids(result.source), [0, 1])
}
