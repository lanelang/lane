///|
test "executable pretty output emphasizes execution structure" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let string_type = @buslane.Type::Primitive(String)
  let println_type = @buslane.Type::Function([string_type], unit_type, Empty)
  let function_type = @buslane.Type::Function([], unit_type, Empty)
  let println = metadata.define_value("println", External, println_type)
  let initialized = metadata.define_value("initialized", Local, int_type)
  let main = metadata.define_value("main", Function, function_type)
  let entry : @buslane_lowering.BuslaneEntry = {
    module_path_text: "Main",
    name: "main",
    value: main,
    type_: function_type,
  }
  let executable : ExecutableProgram = {
    module_path_texts: ["Basic.Io", "Main"],
    program: {
      metadata,
      terms: [
        External(println),
        Let(initialized, Literal(Int(42))),
        Let(
          main,
          Function({
            parameters: [],
            result_type: unit_type,
            body: Literal(Unit),
          }),
        ),
      ],
    },
    externals: {
      builtins: [],
      runtime_imports: [
        {
          value: println,
          symbol: "println",
          signature: { parameters: [String], result: Unit },
          type_: println_type,
        },
      ],
    },
    entry,
    initializers: [Value(initialized, Literal(Int(42)))],
    execution_roots: [Initializer(0), Entry(main)],
    effect_companions: [],
  }
  inspect(
    @prettyprinter.render(executable, width=80),
    content=(
      #|executable {
      #|  modules {
      #|    Basic.Io
      #|    Main
      #|  }
      #|  entry Main.main = value#2 : () -> Unit
      #|  externals {
      #|    runtime_import "println" as value#0 : (String) -> Unit
      #|  }
      #|  initializers {
      #|    init#0 = value#1
      #|  }
      #|  execution_order {
      #|    init#0
      #|    entry value#2
      #|  }
      #|  effect_companions {}
      #|  program {
      #|    buslane {
      #|      metadata {
      #|        external println#0 : (String) -> Unit
      #|        local initialized#1 : Int
      #|        function main#2 : () -> Unit
      #|      }
      #|      external value#0
      #|      let value#1 = 42
      #|      let value#2 = fn() -> Unit {
      #|        ()
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
}
