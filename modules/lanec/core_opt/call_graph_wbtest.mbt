///|
test "Core analysis resolves recursive calls through immutable aliases" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let function_type = @buslane.Type::Function([], unit_type, Empty)
  let recurse = metadata.define_value("recurse", Function, function_type)
  let again = metadata.define_value("again", Local, function_type)
  let main = metadata.define_value("main", Function, function_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      LetRec([
        {
          id: recurse,
          rhs: Function({
            parameters: [],
            result_type: unit_type,
            body: Let(again, Ref(recurse), Call(Ref(again), [])),
          }),
        },
      ]),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(recurse), []),
        }),
      ),
    ],
  }
  let analysis = analyze_core(program, main, [])
  debug_inspect(
    analysis.functions.map(summary => {
      (
        summary.value,
        summary.callees,
        summary.expression_size,
        summary.occurrence,
        summary.is_recursive,
      )
    }),
    content=(
      #|[
      #|  (
      #|    { index: 0 },
      #|    [Some({ index: 0 })],
      #|    4,
      #|    {
      #|      value: { index: 0 },
      #|      use_count: 2,
      #|      call_count: 1,
      #|      callee_only: false,
      #|      escapes: true,
      #|      used_in_effectful_context: false,
      #|      reachable_from_entry: true,
      #|    },
      #|    true,
      #|  ),
      #|  (
      #|    { index: 2 },
      #|    [Some({ index: 0 })],
      #|    2,
      #|    {
      #|      value: { index: 2 },
      #|      use_count: 0,
      #|      call_count: 0,
      #|      callee_only: false,
      #|      escapes: false,
      #|      used_in_effectful_context: false,
      #|      reachable_from_entry: true,
      #|    },
      #|    false,
      #|  ),
      #|]
    ),
  )
}

///|
test "Core analysis summarizes local, recursive, escaping, and unknown calls" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let function_type = @buslane.Type::Function([], unit_type, Empty)
  let external = metadata.define_value("external", External, function_type)
  let first = metadata.define_value("first", Function, function_type)
  let second = metadata.define_value("second", Function, function_type)
  let local_callable = metadata.define_value("local", Local, function_type)
  let escaped = metadata.define_value("escaped", Local, function_type)
  let ignored = metadata.define_value("ignored", Local, unit_type)
  let main = metadata.define_value("main", Function, function_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(external),
      LetRec([
        {
          id: first,
          rhs: Function({
            parameters: [],
            result_type: unit_type,
            body: Call(Ref(second), []),
          }),
        },
        {
          id: second,
          rhs: Function({
            parameters: [],
            result_type: unit_type,
            body: Call(Ref(first), []),
          }),
        },
      ]),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            local_callable,
            Function({
              parameters: [],
              result_type: unit_type,
              body: Call(Ref(external), []),
            }),
            Let(
              escaped,
              Ref(local_callable),
              Let(ignored, Call(Ref(first), []), Call(Ref(local_callable), [])),
            ),
          ),
        }),
      ),
    ],
  }
  let analysis = analyze_core(program, main, [])
  debug_inspect(
    analysis.functions.map(summary => {
      (
        summary.value,
        summary.callees,
        summary.expression_size,
        summary.occurrence,
        summary.is_recursive,
      )
    }),
    content=(
      #|[
      #|  (
      #|    { index: 1 },
      #|    [Some({ index: 2 })],
      #|    2,
      #|    {
      #|      value: { index: 1 },
      #|      use_count: 2,
      #|      call_count: 2,
      #|      callee_only: true,
      #|      escapes: false,
      #|      used_in_effectful_context: false,
      #|      reachable_from_entry: true,
      #|    },
      #|    true,
      #|  ),
      #|  (
      #|    { index: 2 },
      #|    [Some({ index: 1 })],
      #|    2,
      #|    {
      #|      value: { index: 2 },
      #|      use_count: 1,
      #|      call_count: 1,
      #|      callee_only: true,
      #|      escapes: false,
      #|      used_in_effectful_context: false,
      #|      reachable_from_entry: true,
      #|    },
      #|    true,
      #|  ),
      #|  (
      #|    { index: 6 },
      #|    [Some({ index: 1 }), Some({ index: 3 })],
      #|    11,
      #|    {
      #|      value: { index: 6 },
      #|      use_count: 0,
      #|      call_count: 0,
      #|      callee_only: false,
      #|      escapes: false,
      #|      used_in_effectful_context: false,
      #|      reachable_from_entry: true,
      #|    },
      #|    false,
      #|  ),
      #|  (
      #|    { index: 3 },
      #|    [None],
      #|    2,
      #|    {
      #|      value: { index: 3 },
      #|      use_count: 2,
      #|      call_count: 1,
      #|      callee_only: false,
      #|      escapes: true,
      #|      used_in_effectful_context: false,
      #|      reachable_from_entry: true,
      #|    },
      #|    false,
      #|  ),
      #|]
    ),
  )
}
