///|
test "executable pretty output emphasizes execution structure" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let observe_type = @buslane.Type::Function([i64_type], unit_type, Builtin(Io))
  let function_type = @buslane.Type::Function([], unit_type, Builtin(Io))
  let observe = metadata.define_value("observe", External, observe_type)
  let initialized = metadata.define_value("initialized", Value, i64_type)
  let main = metadata.define_value("main", Function, function_type)
  let entry : @buslane_lowering.BuslaneEntry = {
    module_path_text: "Main",
    name: "main",
    value: main,
  }
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: executable_test_program(metadata, [
      External(observe),
      Let(initialized, Literal(I64(42))),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(observe), [Ref(initialized)]),
        }),
      ),
    ]),
    externals: {
      builtins: [],
      runtime_imports: [
        {
          value: observe,
          symbol: "observe",
          signature: { parameters: [I64], result: Unit, },
        },
      ],
    },
    entries: [entry],
  }
  let executable = elaborate(linked, entry, test_execution_profile()).unwrap()
  inspect(
    @prettyprinter.render(executable, width=80),
    content=(
      #|executable {
      #|  entry Main.main = value#2 : () -> Unit ! Io
      #|  externals {
      #|    runtime_import "observe" as value#0 : (I64) -> Unit ! Io
      #|  }
      #|  execution_order {
      #|    initialize value#1
      #|    entry value#2
      #|  }
      #|  program {
      #|    buslane {
      #|      metadata {
      #|        next_unique#3;
      #|        value value#0 = "observe"#0 external : (I64) -> Unit ! Io;
      #|        value value#1 = "initialized"#1 value : I64;
      #|        value value#2 = "main"#2 function : () -> Unit ! Io;
      #|      }
      #|      external value#0
      #|      let value#1 = 42
      #|      let value#2 = fn() -> Unit {
      #|        value#0(value#1)
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
}
