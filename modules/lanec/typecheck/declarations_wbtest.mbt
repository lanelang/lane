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
      #|  boxed : Box[Int]
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
      #|        boxed#1 : type#0[Int]
      #|        option#2 : type#1[String]
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {
      #|      value#0 : tparam#0
      #|      boxed#1 : type#0[Int]
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
      #|  val : F[Int]
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
      #|        val#0 : tparam#0[Int]
      #|      }
      #|      enum Packed#1 {
      #|        hide#0[T#1 : Type](tparam#1)
      #|      }
      #|    }
      #|    type_members {
      #|      type F#0 : [Type] -> Type
      #|    }
      #|    fields {
      #|      val#0 : tparam#0[Int]
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
      #|  read() -> Int
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
      #|  read() -> Int
      #|}
      #|pub fn expose(value : Secret) -> Int ! Console {
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
      #|let int_add : (Int, Int) -> Int = builtin("%i64_add")
      #|let host_clock : () -> Int = extern("clock")
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
      #|  { parameters: [], result: Int },
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
      #|  value : Int
      #|}
      #|let scalar : Int = extern("scalar")
      #|let generic : [A](A) -> A = extern("generic")
      #|let aggregate_parameter : (Box) -> Int = extern("aggregate_parameter")
      #|let aggregate_result : () -> Box = extern("aggregate_result")
      #|fn[E : Effect] open_effect() -> (Int) -> Int ! E {
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
      #|      type_=Primitive(Int),
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
      #|      type_=Function([Constructor({ index: 0 })], Primitive(Int), Empty),
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
      #|      type_=Function([Primitive(Int)], Primitive(Int), Parameter({ index: 1 })),
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
      #|  value : Int
      #|}
      #|let bad : (Box) -> Int = extern("bad")
    ),
    "bad",
    Function([Constructor({ index: 0 })], Primitive(Int), Empty),
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
      #|let open_fd : (String) -> Fd ! VectorOp[Int] = extern("fd.open")
      #|let close_fd : (Handle) -> Unit ! { VectorOp[Int], Io } = extern("fd.close")
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
      #|fn id(value : Int) -> Int {
      #|  value
      #|}
      #|let answer : Int = id(42)
      #|fn use_answer() -> Int {
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
      #|    fn id#0 : (Int) -> Int
      #|    fn use_answer#2 : () -> Int
      #|    let answer#1 : Int
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
      #|fn first(value : Int) -> Int {
      #|  second(value)
      #|}
      #|let base : Int = 1
      #|fn second(value : Int) -> Int {
      #|  first(value)
      #|}
      #|let copied : Int = base
      #|fn use() -> Int {
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
      #|    fn first#0 : (Int) -> Int
      #|    fn second#2 : (Int) -> Int
      #|    fn use#4 : () -> Int
      #|    let base#1 : Int
      #|    let copied#3 : Int
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
      #|let first : Int = second
      #|let second : Int = 1
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
  let result = typecheck_source_file(resolution.source)
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[unresolved_value second @ 2:19-2:25]
    ),
  )
}

///|
test "typecheck top level function bodies see later top level values" {
  let result = expect_typecheck_result(
    (
      #|struct Box {
      #|  value : Int
      #|}
      #|fn read_answer() -> Int {
      #|  answer
      #|}
      #|fn read_box() -> Int {
      #|  box.value
      #|}
      #|let answer : Int = 42
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
      #|        value#0 : Int
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {
      #|      value#0 : Int
      #|    }
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn read_answer#0 : () -> Int
      #|    fn read_box#1 : () -> Int
      #|    let answer#2 : Int
      #|    let box#3 : type#0
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}
