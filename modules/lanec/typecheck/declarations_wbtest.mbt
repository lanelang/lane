///|
test "typecheck custom type declaration environment" {
  let result = expect_declaration_typecheck_result(
    (
      #|struct Box[A] {
      #|  value : A
      #|}
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|struct Uses {
      #|  boxed : Box[I64]
      #|  option : Option[String]
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|declaration_typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      struct Box#0[A#0 : Type] {
      #|        value#0 : tparam#0
      #|      }
      #|      enum Option#1[A#1 : Type] {
      #|        none#0
      #|        some#1(tparam#1)
      #|      }
      #|      struct Uses#2 {
      #|        boxed#1 : type#0[I64]
      #|        option#2 : type#1[String]
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {
      #|      value#0 : tparam#0
      #|      boxed#1 : type#0[I64]
      #|      option#2 : type#1[String]
      #|    }
      #|    variants {
      #|      none#0
      #|      some#1(tparam#1)
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck preserves existential declaration metadata" {
  let result = expect_declaration_typecheck_result(
    (
      #|struct HideF {
      #|  type F : [Type] -> Type
      #|  val : F[I64]
      #|}
      #|enum Packed {
      #|  hide[T](T)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|declaration_typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      struct HideF#0 {
      #|        type F#0 : [Type] -> Type
      #|        val#0 : tparam#0[I64]
      #|      }
      #|      enum Packed#1 {
      #|        hide#0[T#1 : Type](tparam#1)
      #|      }
      #|    }
      #|    type_members {
      #|      type F#0 : [Type] -> Type
      #|    }
      #|    fields {
      #|      val#0 : tparam#0[I64]
      #|    }
      #|    variants {
      #|      hide#0[T#1 : Type](tparam#1)
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "type expression checking requires lexical kind bindings" {
  let file = expect_parse_ok(
    (
      #|struct Apply[F : [Type] -> Type] {
      #|  value : F[I64]
      #|}
    ),
  )
  let resolution = @resolve.resolve_source_file_result(file)
  if !resolution.diagnostics.is_empty() {
    abort(@prettyprinter.render(resolution.diagnostics, width=100))
  }
  guard resolution.source.declarations
    is [Struct({ members: [Field({ type_: body, .. })], .. })] else {
    abort("expected struct field")
  }
  let diagnostics : Array[TypeCheckDiagnostic] = []
  ignore(
    TypeExpressionChecker::{
      source: resolution.source,
      imported_environment: empty_imported_environment(),
      diagnostics,
      expanding: [],
      scope: TypeKindScope::empty(),
    }.synthesize_type(body),
  )
  debug_inspect(
    diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: InternalTypecheckFailure(label="missing type parameter kind metadata"),
      #|    loc: {
      #|      start_offset: 57,
      #|      end_offset: 58,
      #|      start_line: 3,
      #|      start_column: 11,
      #|      end_line: 3,
      #|      end_column: 12,
      #|    },
      #|  },
      #|  {
      #|    kind: KindMismatch(expected=Function([], Type), actual=Type),
      #|    loc: {
      #|      start_offset: 57,
      #|      end_offset: 63,
      #|      start_line: 3,
      #|      start_column: 11,
      #|      end_line: 3,
      #|      end_column: 17,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck effect declaration environment and public interface" {
  let result = expect_declaration_typecheck_result(
    (
      #|pub effect State[S] {
      #|  get() -> S
      #|  put(S) -> Unit
      #|}
      #|effect Console {
      #|  write(String) -> Unit
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|declaration_typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|    effects {
      #|      effect effect#0 State[S#0 : Type] {
      #|        operation operation#0 get -> tparam#0
      #|        operation operation#1 put(tparam#0) -> Unit
      #|      }
      #|      effect effect#1 Console {
      #|        operation operation#2 write(String) -> Unit
      #|      }
      #|    }
      #|    operations {
      #|      operation operation#0 get -> tparam#0
      #|      operation operation#1 put(tparam#0) -> Unit
      #|      operation operation#2 write(String) -> Unit
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
  let checked = expect_checked_source_result(
    (
      #|pub effect State[S] {
      #|  get() -> S
      #|  put(S) -> Unit
      #|}
      #|effect Console {
      #|  write(String) -> Unit
      #|}
    ),
  )
  guard checked.module_interface is Some(interface) else {
    abort("expected module interface")
  }
  inspect(
    module_interface_effect_signatures(interface),
    content="State[1]{get/0->tparam#0,put/1->Unit}",
  )
}

///|
test "typecheck rejects public effect alias exposing private effect" {
  let result = expect_checked_source_result(
    (
      #|effect Console {
      #|  read() -> I64
      #|}
      #|pub type UI = { Console }
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[private effect `Console` in public interface @ 5:1-5:26]
    ),
  )
}

///|
test "typecheck locates private public-interface escapes at annotations" {
  let result = expect_checked_source_result(
    (
      #|struct Secret {}
      #|effect Console {
      #|  read() -> I64
      #|}
      #|pub fn expose(value : Secret) -> I64 ! Console {
      #|  Console::read!()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[
      #|  private type `Secret` in public interface @ 6:23-6:29,
      #|  private effect `Console` in public interface @ 6:40-6:47
      #|]
    ),
  )
}

///|
fn module_interface_effect_signatures(
  interface : @module_interface.ModuleInterface,
) -> String {
  interface.effects
  .map(fn(effect) {
    let operations = effect.operations
      .map(fn(operation) {
        let result = @prettyprinter.render(operation.result.pretty(), width=100)
        "\{operation.name}/\{operation.payload.length()}->\{result}"
      })
      .join(",")
    "\{effect.name}[\{effect.type_parameters.length()}]{\{operations}}"
  })
  .join(";")
}

///|
test "typecheck distinguishes compiler intrinsics from extern bindings" {
  let result = expect_checked_source_result(
    (
      #|let i64_add : (I64, I64) -> I64 = builtin("%i64_add")
      #|let host_clock : () -> I64 = extern("clock")
      #|let host_println : (String) -> Unit ! Io = extern("println")
    ),
  )
  guard result.source is Some(source) else { abort("expected checked source") }
  guard source.declarations[0]
    is Let({ initializer: CompilerIntrinsic(..), .. }) else {
    abort("expected compiler intrinsic")
  }
  guard source.declarations[1]
    is Let({ initializer: ExternBinding(signature=pure_signature, ..), .. }) else {
    abort("expected pure extern binding")
  }
  guard source.declarations[2]
    is Let({ initializer: ExternBinding(signature=io_signature, ..), .. }) else {
    abort("expected Io extern binding")
  }
  debug_inspect(
    [pure_signature, io_signature],
    content=(
      #|[
      #|  { parameters: [], result: I64 },
      #|  { parameters: [String], result: Unit },
      #|]
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck rejects unsupported extern ABI shapes" {
  let result = expect_typecheck_result(
    (
      #|effect Log {
      #|  write(String) -> Unit
      #|}
      #|struct Box {
      #|  value : I64
      #|}
      #|let scalar : I64 = extern("scalar")
      #|let generic : [A](A) -> A = extern("generic")
      #|let aggregate_parameter : (Box) -> I64 = extern("aggregate_parameter")
      #|let aggregate_result : () -> Box = extern("aggregate_result")
      #|fn[E : Effect] open_effect() -> (I64) -> I64 ! E {
      #|  extern("open_effect")
      #|}
      #|let algebraic_effect : () -> Unit ! Log = extern("algebraic_effect")
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: InvalidExternType(
      #|      name="scalar",
      #|      type_=Primitive(I64),
      #|      restriction=FunctionRequired,
      #|    ),
      #|    loc: {
      #|      start_offset: 99,
      #|      end_offset: 115,
      #|      start_line: 8,
      #|      start_column: 20,
      #|      end_line: 8,
      #|      end_column: 36,
      #|    },
      #|  },
      #|  {
      #|    kind: InvalidExternType(
      #|      name="generic",
      #|      type_=Forall(
      #|        [{ id: { index: 0 }, name: "A", kind: Type }],
      #|        Function([Parameter({ index: 0 })], Parameter({ index: 0 }), Empty),
      #|      ),
      #|      restriction=MonomorphicRequired,
      #|    ),
      #|    loc: {
      #|      start_offset: 144,
      #|      end_offset: 161,
      #|      start_line: 9,
      #|      start_column: 29,
      #|      end_line: 9,
      #|      end_column: 46,
      #|    },
      #|  },
      #|  {
      #|    kind: InvalidExternType(
      #|      name="aggregate_parameter",
      #|      type_=Function([Constructor({ index: 0 })], Primitive(I64), Empty),
      #|      restriction=DirectParameterRequired(index=0),
      #|    ),
      #|    loc: {
      #|      start_offset: 203,
      #|      end_offset: 232,
      #|      start_line: 10,
      #|      start_column: 42,
      #|      end_line: 10,
      #|      end_column: 71,
      #|    },
      #|  },
      #|  {
      #|    kind: InvalidExternType(
      #|      name="aggregate_result",
      #|      type_=Function([], Constructor({ index: 0 }), Empty),
      #|      restriction=DirectResultRequired,
      #|    ),
      #|    loc: {
      #|      start_offset: 268,
      #|      end_offset: 294,
      #|      start_line: 11,
      #|      start_column: 36,
      #|      end_line: 11,
      #|      end_column: 62,
      #|    },
      #|  },
      #|  {
      #|    kind: InvalidExternType(
      #|      name="open_effect",
      #|      type_=Function([Primitive(I64)], Primitive(I64), Parameter({ index: 1 })),
      #|      restriction=ExternalEffectRowRequired,
      #|    ),
      #|    loc: {
      #|      start_offset: 348,
      #|      end_offset: 369,
      #|      start_line: 13,
      #|      start_column: 3,
      #|      end_line: 13,
      #|      end_column: 24,
      #|    },
      #|  },
      #|  {
      #|    kind: InvalidExternType(
      #|      name="algebraic_effect",
      #|      type_=Function([], Primitive(Unit), Singleton({ index: 0 }, [])),
      #|      restriction=ExternalEffectRowRequired,
      #|    ),
      #|    loc: {
      #|      start_offset: 414,
      #|      end_offset: 440,
      #|      start_line: 15,
      #|      start_column: 43,
      #|      end_line: 15,
      #|      end_column: 69,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "invalid extern ABI produces checked error recovery" {
  let expression = expect_checked_let_initializer(
    (
      #|struct Box {
      #|  value : I64
      #|}
      #|let bad : (Box) -> I64 = extern("bad")
    ),
    "bad",
    Function([Constructor({ index: 0 })], Primitive(I64), Empty),
  )
  assert_true(expression is ErrorRecovery(..))
}

///|
test "typecheck accepts external types and closed external effect rows" {
  let result = expect_checked_source_result(
    (
      #|extern type Fd : Type
      #|extern type VectorOp[A : Type] : Effect
      #|type Handle = Fd
      #|let open_fd : (String) -> Fd ! VectorOp[I64] = extern("fd.open")
      #|let close_fd : (Handle) -> Unit ! { VectorOp[I64], Io } = extern("fd.close")
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
  guard result.source is Some(source) else { abort("expected checked source") }
  guard source.declarations[0] is ExternalType(fd) else {
    abort("expected external type")
  }
  guard source.declarations[1] is Effect(vector_op) else {
    abort("expected external effect")
  }
  debug_inspect(
    (
      fd.name,
      vector_op.name,
      vector_op.flavor,
      vector_op.type_parameters.length(),
      vector_op.operations.length(),
    ),
    content=(
      #|("Fd", "VectorOp", External, 1, 0)
    ),
  )
}

///|
test "typecheck rejects parameterized external host types" {
  let result = expect_typecheck_result("extern type Box[A] : Type")
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: ExternalTypeParametersNotSupported(name="Box"),
      #|    loc: {
      #|      start_offset: 12,
      #|      end_offset: 37,
      #|      start_line: 2,
      #|      start_column: 1,
      #|      end_line: 2,
      #|      end_column: 26,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck top level values and direct calls" {
  let result = expect_typecheck_result(
    (
      #|fn id(value : I64) -> I64 {
      #|  value
      #|}
      #|let answer : I64 = id(42)
      #|fn use_answer() -> I64 {
      #|  answer
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn id#0 : (I64) -> I64
      #|    fn use_answer#2 : () -> I64
      #|    let answer#1 : I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck top level functions recurse and values stay ordered" {
  let result = expect_typecheck_result(
    (
      #|fn first(value : I64) -> I64 {
      #|  second(value)
      #|}
      #|let base : I64 = 1
      #|fn second(value : I64) -> I64 {
      #|  first(value)
      #|}
      #|let copied : I64 = base
      #|fn use() -> I64 {
      #|  copied
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn first#0 : (I64) -> I64
      #|    fn second#2 : (I64) -> I64
      #|    fn use#4 : () -> I64
      #|    let base#1 : I64
      #|    let copied#3 : I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck reports forward top level value use" {
  let file = expect_parse_ok(
    (
      #|let first : I64 = second
      #|let second : I64 = 1
    ),
  )
  let resolution = @resolve.resolve_source_file_result(file)
  debug_inspect(
    resolution.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: UnresolvedValue("second"),
      #|    loc: {
      #|      start_offset: 30,
      #|      end_offset: 36,
      #|      start_line: 2,
      #|      start_column: 19,
      #|      end_line: 2,
      #|      end_column: 25,
      #|    },
      #|  },
      #|]
    ),
  )
  guard typecheck_source_file(resolution.source)
    is Err(InvalidInputMetadata([UnresolvedValue(name="second", ..)])) else {
    fail("expected unresolved value to be rejected as invalid input metadata")
  }
}

///|
test "typecheck top level function bodies see later top level values" {
  let result = expect_typecheck_result(
    (
      #|struct Box {
      #|  value : I64
      #|}
      #|fn read_answer() -> I64 {
      #|  answer
      #|}
      #|fn read_box() -> I64 {
      #|  box.value
      #|}
      #|let answer : I64 = 42
      #|let box : Box = Box::{ value: answer }
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      struct Box#0 {
      #|        value#0 : I64
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {
      #|      value#0 : I64
      #|    }
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn read_answer#0 : () -> I64
      #|    fn read_box#1 : () -> I64
      #|    let answer#2 : I64
      #|    let box#3 : type#0
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}
