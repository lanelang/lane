///|
test "linked executable lowers through the LoisVM boundary" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let main = metadata.define_value("main", Function, main_type)
  let linked : LinkedExecutableProgram = {
    module_path_texts: ["Main"],
    program: {
      metadata,
      terms: [
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
    externals: { builtins: [] },
    entry: {
      module_path_text: "Main",
      name: "main",
      value: main,
      type_: main_type,
    },
    runtime_effect_operations: [],
  }
  assert_true(
    linked.lower_to_loisvm_bytecode()
    is Ok({ entry: { value: 1 }, functions: [BytecodeBody(_)], .. }),
  )
}
