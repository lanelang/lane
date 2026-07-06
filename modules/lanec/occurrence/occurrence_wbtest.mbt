///|
test "occurrence summarizes calls escapes effects and selected-entry reachability" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let console = metadata.define_effect("Console", [])
  let unit = @buslane.Type::Primitive(Unit)
  let pure_function = @buslane.Type::Function([], unit, Empty)
  let effectful_function = @buslane.Type::Function(
    [],
    unit,
    Singleton(console, []),
  )
  let main = metadata.define_value("main", Function, pure_function)
  let called = metadata.define_value("called", Function, pure_function)
  let escaped = metadata.define_value("escaped", Function, pure_function)
  let effectful = metadata.define_value(
    "effectful",
    Function,
    effectful_function,
  )
  let dead = metadata.define_value("dead", Function, pure_function)
  let local_value = metadata.define_value("local", Local, pure_function)
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        called,
        Function({ parameters: [], result_type: unit, body: Literal(Unit) }),
      ),
      Let(
        escaped,
        Function({ parameters: [], result_type: unit, body: Literal(Unit) }),
      ),
      Let(
        effectful,
        Function({ parameters: [], result_type: unit, body: Literal(Unit) }),
      ),
      Let(
        dead,
        Function({ parameters: [], result_type: unit, body: Literal(Unit) }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit,
          body: Let(
            local_value,
            Ref(escaped),
            Let(
              { index: 6 },
              Call(Ref(called), []),
              Call(Ref(effectful), [Ref(local_value)]),
            ),
          ),
        }),
      ),
    ],
  }
  let summary = analyze({ program, entry: main, roots: [] })
  debug_inspect(
    summary,
    content=(
      #|{
      #|  entry: { index: 0 },
      #|  roots: [],
      #|  facts: [
      #|    {
      #|      value: { index: 0 },
      #|      use_count: 0,
      #|      call_count: 0,
      #|      callee_only: false,
      #|      escapes: false,
      #|      used_in_effectful_context: false,
      #|      reachable_from_entry: true,
      #|    },
      #|    {
      #|      value: { index: 1 },
      #|      use_count: 1,
      #|      call_count: 1,
      #|      callee_only: true,
      #|      escapes: false,
      #|      used_in_effectful_context: false,
      #|      reachable_from_entry: true,
      #|    },
      #|    {
      #|      value: { index: 2 },
      #|      use_count: 1,
      #|      call_count: 0,
      #|      callee_only: false,
      #|      escapes: true,
      #|      used_in_effectful_context: false,
      #|      reachable_from_entry: true,
      #|    },
      #|    {
      #|      value: { index: 3 },
      #|      use_count: 1,
      #|      call_count: 1,
      #|      callee_only: true,
      #|      escapes: false,
      #|      used_in_effectful_context: true,
      #|      reachable_from_entry: true,
      #|    },
      #|    {
      #|      value: { index: 4 },
      #|      use_count: 0,
      #|      call_count: 0,
      #|      callee_only: false,
      #|      escapes: false,
      #|      used_in_effectful_context: false,
      #|      reachable_from_entry: false,
      #|    },
      #|    {
      #|      value: { index: 5 },
      #|      use_count: 1,
      #|      call_count: 0,
      #|      callee_only: false,
      #|      escapes: true,
      #|      used_in_effectful_context: false,
      #|      reachable_from_entry: true,
      #|    },
      #|    {
      #|      value: { index: 6 },
      #|      use_count: 0,
      #|      call_count: 0,
      #|      callee_only: false,
      #|      escapes: false,
      #|      used_in_effectful_context: false,
      #|      reachable_from_entry: true,
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "occurrence treats explicit roots as reachable" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit = @buslane.Type::Primitive(Unit)
  let function_type = @buslane.Type::Function([], unit, Empty)
  let main = metadata.define_value("main", Function, function_type)
  let runtime_root = metadata.define_value("runtime", External, function_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        main,
        Function({ parameters: [], result_type: unit, body: Literal(Unit) }),
      ),
      External(runtime_root),
    ],
  }
  let summary = analyze({ program, entry: main, roots: [runtime_root] })
  debug_inspect(
    summary.facts,
    content=(
      #|[
      #|  {
      #|    value: { index: 0 },
      #|    use_count: 0,
      #|    call_count: 0,
      #|    callee_only: false,
      #|    escapes: false,
      #|    used_in_effectful_context: false,
      #|    reachable_from_entry: true,
      #|  },
      #|  {
      #|    value: { index: 1 },
      #|    use_count: 0,
      #|    call_count: 0,
      #|    callee_only: false,
      #|    escapes: false,
      #|    used_in_effectful_context: false,
      #|    reachable_from_entry: true,
      #|  },
      #|]
    ),
  )
}
