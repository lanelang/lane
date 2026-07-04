///|
using @prettyprinter {
  type Document,
  char,
  empty,
  line,
  nest,
  separate,
  space,
  surround,
  text,
}

///|
pub impl @prettyprinter.Pretty for BuslaneRuntimeValue with fn pretty(
  value : BuslaneRuntimeValue,
) {
  match value.kind {
    Int(value) => text("int") + space + text(value.to_string())
    Bool(value) => text("bool") + space + text(value.to_string())
    String(value) => text("string") + space + quoted(value)
    Unit => text("unit")
    Data(data_constructor~, arguments~) =>
      text("data_value") +
      space +
      data_constructor.pretty() +
      space +
      braced_block(arguments.map(BuslaneRuntimeValue::pretty))
    Closure(..) | NativeFunction(_) => text("<function>")
    TypeClosure(..) => text("<type-function>")
    ResumeContinuation(_) => text("<resume-continuation>")
    External(id) => text("external_value") + space + id.pretty()
  }
}

///|
/// Renders a runtime value with the Buslane type selected by a caller-facing
/// entry point.
pub fn BuslaneRuntimeValue::pretty_with_type(
  value : BuslaneRuntimeValue,
  type_ : @buslane.Type,
) -> Document {
  runtime_value_source_doc(value) + space + text(":") + space + type_.pretty()
}

///|
fn runtime_value_source_doc(value : BuslaneRuntimeValue) -> Document {
  match value.kind {
    Int(value) => text(value.to_string())
    Bool(value) => text(value.to_string())
    String(value) => quoted(value)
    Unit => text("()")
    Closure(..) | TypeClosure(..) | NativeFunction(_) | ResumeContinuation(_) =>
      text("<function>")
    _ => value.pretty()
  }
}

///|
fn runtime_binding_doc(
  binding : (@buslane.ValueId, BuslaneRuntimeValue),
) -> Document {
  let (id, value) = binding
  text("value") + space + id.pretty() + space + braced_block([value.pretty()])
}

///|
impl @prettyprinter.Pretty for BuslaneRuntimeEnvironment with fn pretty(
  environment : BuslaneRuntimeEnvironment,
) {
  let docs = environment.values.to_array().map(runtime_binding_doc)
  let docs = match environment.parent {
    None => docs
    Some(parent) => docs + [section("parent", [parent.pretty()])]
  }
  text("buslane_environment") + space + braced_block(docs)
}

///|
pub impl @prettyprinter.Pretty for BuslaneRuntimeProgram with fn pretty(
  program : BuslaneRuntimeProgram,
) {
  text("buslane_runtime_program") +
  space +
  braced_block([section("globals", [program.globals.pretty()])])
}

///|
pub impl @prettyprinter.Pretty for BuslaneRuntimeError with fn pretty(
  error : BuslaneRuntimeError,
) {
  match error {
    InvalidProgram(diagnostics) =>
      text("invalid_program") +
      space +
      braced_block(diagnostics.map(@buslane.VerifyDiagnostic::pretty))
    UnboundValue(id) => text("unbound_value") + space + id.pretty()
    MissingExternal(id) => text("missing_external") + space + id.pretty()
    UnhandledOperation(id) => text("unhandled_operation") + space + id.pretty()
    InvalidRuntimeEffectHandler(id) =>
      text("invalid_runtime_effect_handler") + space + id.pretty()
    ExternalFailure(id~, message~) =>
      text("external_failure") + space + id.pretty() + space + quoted(message)
    InvalidValue(message~) => text("invalid_value") + space + quoted(message)
  }
}

///|
fn section(label : String, docs : Array[Document]) -> Document {
  text(label) + space + braced_block(docs)
}

///|
fn braced_block(docs : Array[Document]) -> Document {
  if docs.is_empty() {
    surround(char('{'), char('}'), empty)
  } else {
    surround(char('{'), line + char('}'), nest(line + separate(line, docs)))
  }
}

///|
fn quoted(value : String) -> Document {
  text("\"") + text(value) + text("\"")
}
