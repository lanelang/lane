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
pub impl @prettyprinter.Pretty for TypeId with fn pretty(id : TypeId) {
  text("type#\{id.index}")
}

///|
pub impl @prettyprinter.Pretty for TypeParameterId with fn pretty(
  id : TypeParameterId,
) {
  text("tparam#\{id.index}")
}

///|
pub impl @prettyprinter.Pretty for ValueId with fn pretty(id : ValueId) {
  text("value#\{id.index}")
}

///|
pub impl @prettyprinter.Pretty for DataConId with fn pretty(id : DataConId) {
  text("datacon#\{id.index}")
}

///|
pub impl @prettyprinter.Pretty for EffectId with fn pretty(id : EffectId) {
  text("effect#\{id.index}")
}

///|
pub impl @prettyprinter.Pretty for OperationId with fn pretty(id : OperationId) {
  text("operation#\{id.index}")
}

///|
/// An occurrence is quoted because it is arbitrary text — generated binders
/// use characters no identifier syntax admits — and the unique follows it, so
/// the pair is one lexable token sequence rather than a bare word.
pub impl @prettyprinter.Pretty for BuslaneName with fn pretty(
  name : BuslaneName,
) {
  quoted(name.occurrence) + text("#\{name.unique.value}")
}

///|
pub impl @prettyprinter.Pretty for Kind with fn pretty(kind : Kind) {
  match kind {
    Type => text("Type")
    Effect => text("Effect")
    Function(parameters, result) =>
      bracketed_inline(parameters.map(Kind::pretty)) +
      space +
      text("->") +
      space +
      result.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for PrimitiveType with fn pretty(
  primitive : PrimitiveType,
) {
  match primitive {
    Unit => text("Unit")
    Bool => text("Bool")
    I64 => text("I64")
    I32 => text("I32")
    Char => text("Char")
    F64 => text("F64")
    F32 => text("F32")
    String => text("String")
    Byte => text("Byte")
    Bytes => text("Bytes")
  }
}

///|
pub impl @prettyprinter.Pretty for Type with fn pretty(type_ : Type) {
  match type_ {
    Primitive(primitive) => primitive.pretty()
    Parameter(parameter) => parameter.pretty()
    Constructor(type_id) => type_id.pretty()
    Apply(callee, arguments) =>
      callee.pretty() + generic_arguments_doc(arguments)
    TypeLambda(parameters, body) =>
      text("type") +
      space +
      bracketed_inline(parameters.map(TypeParameterId::pretty)) +
      space +
      text("=>") +
      space +
      body.pretty()
    Function(parameters, result, effect) =>
      function_type_doc(parameters, result, effect)
    Forall(parameters, body) =>
      text("forall") +
      space +
      bracketed_inline(parameters.map(TypeParameterId::pretty)) +
      text(".") +
      space +
      body.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for Effect with fn pretty(effect : Effect) {
  match effect {
    Empty => text("{}")
    Io => text("Io")
    Singleton(id, arguments) => id.pretty() + generic_arguments_doc(arguments)
    Parameter(parameter) => parameter.pretty()
    Union(effects) => braced_inline(effects.map(Effect::pretty))
  }
}

///|
/// An argument is a type unless prefixed with `!`, which marks an effect. A
/// bare type parameter is the one spelling that could mean either, so the
/// marker goes on the effect side rather than on both.
pub impl @prettyprinter.Pretty for GenericArgument with fn pretty(
  argument : GenericArgument,
) {
  match argument {
    TypeArgument(type_) => type_.pretty()
    EffectArgument(effect) => text("!") + effect.pretty()
  }
}

///|
/// A literal carries its type wherever the spelling would otherwise be
/// ambiguous: a bare integer is `I64`, and the rest name themselves. Floats
/// use their exact bit pattern so one spelling round-trips every value,
/// including signed zero, infinities, and NaN payloads.
pub impl @prettyprinter.Pretty for Literal with fn pretty(literal : Literal) {
  match literal {
    Unit => text("()")
    Bool(value) => text(value.to_string())
    I64(value) => text(value.to_string())
    I32(value) => call_doc("i32", [text(value.to_string())])
    Char(value) => call_doc("char", [text(value.to_string())])
    F64(value) => call_doc("f64", [text(f64_bits_text(value))])
    F32(value) => call_doc("f32", [text(f32_bits_text(value))])
    String(value) => quoted(value)
  }
}

///|
fn call_doc(name : String, arguments : Array[Document]) -> Document {
  text(name) + parenthesized_inline(arguments)
}

///|
fn f64_bits_text(value : Double) -> String {
  "0x" + value.reinterpret_as_uint64().to_string(radix=16).pad_start(16, '0')
}

///|
fn f32_bits_text(value : Float) -> String {
  "0x" + value.reinterpret_as_uint().to_string(radix=16).pad_start(8, '0')
}

///|
pub impl @prettyprinter.Pretty for ValueKind with fn pretty(kind : ValueKind) {
  match kind {
    Function => text("function")
    Value => text("value")
    External => text("external")
    Parameter => text("parameter")
    Local => text("local")
    MatchBinder => text("match_binder")
  }
}

///|
pub impl @prettyprinter.Pretty for TypeInfo with fn pretty(info : TypeInfo) {
  external_prefix(info.flavor is External) +
  text("type") +
  space +
  info.name.pretty() +
  type_parameters_doc(info.parameters) +
  space +
  braced_block(info.constructors.map(DataConId::pretty))
}

///|
pub impl @prettyprinter.Pretty for TypeParameterInfo with fn pretty(
  info : TypeParameterInfo,
) {
  external_prefix(info.flavor is External) +
  text("type_parameter") +
  space +
  info.name.pretty() +
  space +
  text(":") +
  space +
  info.kind.pretty()
}

///|
pub impl @prettyprinter.Pretty for ValueInfo with fn pretty(info : ValueInfo) {
  info.kind.pretty() +
  space +
  info.name.pretty() +
  space +
  text(":") +
  space +
  info.type_.pretty()
}

///|
pub impl @prettyprinter.Pretty for DataConInfo with fn pretty(
  info : DataConInfo,
) {
  text("datacon") +
  space +
  info.name.pretty() +
  type_parameters_doc(info.hidden_type_parameters) +
  parenthesized_inline(info.payload_types.map(Type::pretty)) +
  space +
  text(":") +
  space +
  info.owner.pretty()
}

///|
pub impl @prettyprinter.Pretty for EffectInfo with fn pretty(info : EffectInfo) {
  external_prefix(info.flavor is External) +
  text("effect") +
  space +
  info.name.pretty() +
  type_parameters_doc(info.parameters) +
  space +
  braced_block(info.operations.map(OperationId::pretty))
}

///|
pub impl @prettyprinter.Pretty for OperationInfo with fn pretty(
  info : OperationInfo,
) {
  text("operation") +
  space +
  info.name.pretty() +
  type_parameters_doc(info.hidden_type_parameters) +
  parenthesized_inline(info.payload_types.map(Type::pretty)) +
  space +
  text("->") +
  space +
  info.result_type.pretty() +
  space +
  text(":") +
  space +
  info.owner.pretty()
}

///|
pub impl @prettyprinter.Pretty for MetadataRegistry with fn pretty(
  metadata : MetadataRegistry,
) {
  text("metadata") + space + braced_block(metadata_declarations(metadata))
}

///|
pub impl @prettyprinter.Pretty for Program with fn pretty(program : Program) {
  text("buslane") +
  space +
  braced_block([program.metadata.pretty()] + program.terms.map(TopTerm::pretty))
}

///|
pub impl @prettyprinter.Pretty for TopTerm with fn pretty(term : TopTerm) {
  match term {
    Let(id, expr) =>
      text("let") +
      space +
      id.pretty() +
      space +
      text("=") +
      space +
      expr.pretty()
    LetRec(bindings) =>
      text("letrec") +
      space +
      braced_block(bindings.map(RecursiveBinding::pretty))
    External(id) => text("external") + space + id.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for RecursiveBinding with fn pretty(
  binding : RecursiveBinding,
) {
  binding.id.pretty() + space + text("=") + space + binding.rhs.pretty()
}

///|
pub impl @prettyprinter.Pretty for Expr with fn pretty(expr : Expr) {
  match expr {
    Ref(id) => id.pretty()
    Literal(literal) => literal.pretty()
    Function(function) => function.pretty()
    Call(callee, arguments) =>
      callee.pretty() + parenthesized_inline(arguments.map(Expr::pretty))
    TypeLambda(parameters, body) =>
      text("fn") +
      type_parameters_doc(parameters) +
      space +
      braced_block([body.pretty()])
    TypeApply(callee, arguments) =>
      callee.pretty() + generic_arguments_doc(arguments)
    Construct(construct) => construct.pretty()
    Let(id, initializer, body) =>
      text("let") +
      space +
      id.pretty() +
      space +
      text("=") +
      space +
      initializer.pretty() +
      space +
      text("in") +
      line +
      body.pretty()
    LetRec(bindings, body) =>
      text("letrec") +
      space +
      braced_block(bindings.map(RecursiveBinding::pretty)) +
      space +
      text("in") +
      line +
      body.pretty()
    Match(match_) => match_.pretty()
    Perform(perform) => perform.pretty()
    Handle(handle) => handle.pretty()
    Resume(id) => text("resume") + space + id.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for FunctionExpr with fn pretty(
  function : FunctionExpr,
) {
  text("fn") +
  parenthesized_inline(function.parameters.map(ValueId::pretty)) +
  space +
  text("->") +
  space +
  function.result_type.pretty() +
  space +
  braced_block([function.body.pretty()])
}

///|
pub impl @prettyprinter.Pretty for ConstructExpr with fn pretty(
  construct : ConstructExpr,
) {
  construct.data_constructor.pretty() +
  type_and_witness_arguments_doc(
    construct.type_arguments,
    construct.hidden_witnesses,
  ) +
  parenthesized_inline(construct.payloads.map(Expr::pretty))
}

///|
pub impl @prettyprinter.Pretty for MatchExpr with fn pretty(match_ : MatchExpr) {
  text("match") +
  space +
  match_.scrutinee.pretty() +
  space +
  text("as") +
  space +
  match_.binder.pretty() +
  space +
  text("->") +
  space +
  match_.result_type.pretty() +
  space +
  braced_block(match_.alternatives.map(Alternative::pretty))
}

///|
pub impl @prettyprinter.Pretty for PerformExpr with fn pretty(
  perform : PerformExpr,
) {
  text("perform") +
  space +
  perform.operation.pretty() +
  type_and_witness_arguments_doc(
    perform.effect_arguments,
    perform.hidden_witnesses,
  ) +
  parenthesized_inline(perform.payloads.map(Expr::pretty))
}

///|
pub impl @prettyprinter.Pretty for HandleExpr with fn pretty(
  handle : HandleExpr,
) {
  text("handle") +
  space +
  handle.body.pretty() +
  space +
  text("as") +
  space +
  handle.result_binder.pretty() +
  space +
  text("->") +
  space +
  handle.result_type.pretty() +
  space +
  braced_block(
    handle.handlers.map(HandlerTable::pretty) +
    [text("final") + space + text("=>") + space + handle.final_body.pretty()],
  )
}

///|
pub impl @prettyprinter.Pretty for HandlerTable with fn pretty(
  table : HandlerTable,
) {
  table.handled_effect.pretty() +
  space +
  braced_block(table.operations.map(OperationAlternative::pretty))
}

///|
pub impl @prettyprinter.Pretty for OperationAlternative with fn pretty(
  alternative : OperationAlternative,
) {
  alternative.operation.pretty() +
  type_parameters_doc(alternative.type_binders) +
  parenthesized_inline(alternative.payload_binders.map(ValueId::pretty)) +
  space +
  text("resume") +
  space +
  alternative.resume_binder.pretty() +
  space +
  text("=>") +
  space +
  alternative.body.pretty()
}

///|
pub impl @prettyprinter.Pretty for Alternative with fn pretty(
  alternative : Alternative,
) {
  alternative_pattern_doc(alternative) +
  space +
  text("=>") +
  space +
  alternative.body.pretty()
}

///|
pub impl @prettyprinter.Pretty for AltCon with fn pretty(alt : AltCon) {
  match alt {
    Default => text("_")
    Literal(literal) => literal.pretty()
    DataCon(id) => id.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for VerifyResult with fn pretty(
  result : VerifyResult,
) {
  text("verify_result") +
  space +
  braced_block(result.diagnostics.map(VerifyDiagnostic::pretty))
}

///|
pub impl @prettyprinter.Pretty for VerifyDiagnostic with fn pretty(
  diagnostic : VerifyDiagnostic,
) {
  if diagnostic.provenance.is_empty() {
    diagnostic.kind.pretty()
  } else {
    diagnostic.kind.pretty() +
    space +
    text("at") +
    space +
    provenance_doc(diagnostic.provenance)
  }
}

///|
/// Renders a diagnostic's path outermost first, so a report reads as the
/// route the verifier took to reach it.
fn provenance_doc(frames : Array[VerifyFrame]) -> Document {
  let mut doc = empty
  for index, frame in frames {
    if index > 0 {
      doc = doc + space + text("/") + space
    }
    doc = doc + frame.pretty()
  }
  doc
}

///|
pub impl @prettyprinter.Pretty for VerifyFrame with fn pretty(
  frame : VerifyFrame,
) {
  match frame {
    Metadata(anchor) => anchor.pretty()
    TopTerm(id) => text("term") + space + id.pretty()
    Expression(label) => label.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for MetadataAnchor with fn pretty(
  anchor : MetadataAnchor,
) {
  match anchor {
    Type(id) => text("type") + space + id.pretty()
    DataConstructor(id) => text("data_constructor") + space + id.pretty()
    Effect(id) => text("effect") + space + id.pretty()
    Operation(id) => text("operation") + space + id.pretty()
    Value(id) => text("value") + space + id.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for ExprLabel with fn pretty(label : ExprLabel) {
  match label {
    Ref(id) => text("ref") + space + id.pretty()
    Literal => text("literal")
    Function => text("fn")
    Call => text("call")
    TypeLambda => text("type_lambda")
    TypeApply => text("type_apply")
    Construct(id) => text("construct") + space + id.pretty()
    Let(id) => text("let") + space + id.pretty()
    LetRec => text("letrec")
    Match => text("match")
    Perform(id) => text("perform") + space + id.pretty()
    Handle => text("handle")
    Resume(id) => text("resume") + space + id.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for VerifyDiagnosticKind with fn pretty(
  kind : VerifyDiagnosticKind,
) {
  match kind {
    UnknownType(id) => text("unknown_type") + space + id.pretty()
    UnknownTypeParameter(id) =>
      text("unknown_type_parameter") + space + id.pretty()
    UnknownValue(id) => text("unknown_value") + space + id.pretty()
    UnknownDataConstructor(id) =>
      text("unknown_data_constructor") + space + id.pretty()
    UnknownEffect(id) => text("unknown_effect") + space + id.pretty()
    UnknownOperation(id) => text("unknown_operation") + space + id.pretty()
    KindMismatch(expected~, actual~) =>
      text("kind_mismatch") +
      space +
      braced_block([
        text("expected ") + expected.pretty(),
        text("actual ") + actual.pretty(),
      ])
    InvalidBinderKind(value~, actual~) =>
      text("invalid_binder_kind") +
      space +
      braced_block([
        text("value ") + value.pretty(),
        text("actual ") + actual.pretty(),
      ])
    EffectFlavorMismatch(parameter~, argument~) =>
      text("effect_flavor_mismatch") +
      space +
      braced_block([
        text("parameter ") + parameter.pretty(),
        text("argument ") + argument.pretty(),
      ])
    ExpectedTypeArgument(effect) =>
      text("expected_type_argument") + space + effect.pretty()
    ExpectedEffectArgument(type_) =>
      text("expected_effect_argument") + space + type_.pretty()
    TypeNormalizationFailure(error) =>
      text("type_normalization_failure") + space + text("\{Repr(error)}")
    TypeSubstitutionFailure(error) =>
      text("type_substitution_failure") + space + text("\{Repr(error)}")
    TypeMismatch(expected~, actual~) =>
      text("type_mismatch") +
      space +
      braced_block([
        text("expected ") + expected.pretty(),
        text("actual ") + actual.pretty(),
      ])
    EffectMismatch(expected~, actual~) =>
      text("effect_mismatch") +
      space +
      braced_block([
        text("expected ") + expected.pretty(),
        text("actual ") + actual.pretty(),
      ])
    NotFunction(type_) => text("not_function") + space + type_.pretty()
    NotForall(type_) => text("not_forall") + space + type_.pretty()
    ArityMismatch(expected~, actual~) =>
      text("arity_mismatch") +
      space +
      braced_block([text("expected \{expected}"), text("actual \{actual}")])
    InvalidExternal(id) => text("invalid_external") + space + id.pretty()
    InvalidLetRecRhs(id) => text("invalid_letrec_rhs") + space + id.pretty()
    InvalidAlternativeBinderCount => text("invalid_alternative_binder_count")
    DuplicateDefaultAlternative => text("duplicate_default_alternative")
    DefaultAlternativeNotLast => text("default_alternative_not_last")
    DuplicateAlternative => text("duplicate_alternative")
    NonExhaustiveMatch => text("non_exhaustive_match")
    InvalidCharLiteral(value) => text("invalid_char_literal \{value}")
  }
}

///|
fn generic_arguments_doc(arguments : Array[GenericArgument]) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    bracketed_inline(arguments.map(GenericArgument::pretty))
  }
}

///|
/// A function-typed result is parenthesized so a latent effect always attaches
/// to exactly one arrow: `(A) -> (B) -> C ! E` would otherwise not say which
/// arrow performs `E`.
fn function_type_doc(
  parameters : Array[Type],
  result : Type,
  effect : Effect,
) -> Document {
  let result_doc = if result is Function(_, _, _) {
    surround(char('('), char(')'), result.pretty())
  } else {
    result.pretty()
  }
  let base = parenthesized_inline(parameters.map(Type::pretty)) +
    space +
    text("->") +
    space +
    result_doc
  match effect {
    Empty => base
    _ => base + space + text("!") + space + effect.pretty()
  }
}

///|
fn type_parameters_doc(parameters : Array[TypeParameterId]) -> Document {
  if parameters.is_empty() {
    empty
  } else {
    bracketed_inline(parameters.map(TypeParameterId::pretty))
  }
}

///|
fn type_and_witness_arguments_doc(
  arguments : Array[GenericArgument],
  witnesses : Array[GenericArgument],
) -> Document {
  if arguments.is_empty() && witnesses.is_empty() {
    empty
  } else if witnesses.is_empty() {
    bracketed_inline(arguments.map(GenericArgument::pretty))
  } else {
    surround(
      char('['),
      char(']'),
      join_comma(arguments.map(GenericArgument::pretty)) +
      text(";") +
      space +
      join_comma(witnesses.map(GenericArgument::pretty)),
    )
  }
}

///|
/// Every metadata entity is declared once, flat and identity-complete: its id,
/// its `name#unique`, and its shape. Nesting a data constructor inside its
/// owner would read better but cannot round-trip, since an entity may legally
/// exist without its owner listing it.
fn metadata_declarations(metadata : MetadataRegistry) -> Array[Document] {
  let declarations : Array[Document] = []
  for index, info in metadata.types {
    declarations.push(type_declaration({ index, }, info))
  }
  for index, info in metadata.type_parameters {
    declarations.push(type_parameter_declaration({ index, }, info))
  }
  for index, info in metadata.data_constructors {
    declarations.push(data_constructor_declaration({ index, }, info))
  }
  for index, info in metadata.values {
    declarations.push(value_declaration({ index, }, info))
  }
  for index, info in metadata.effects {
    declarations.push(effect_declaration({ index, }, info))
  }
  for index, info in metadata.operations {
    declarations.push(operation_declaration({ index, }, info))
  }
  declarations
}

///|
fn declaration_head(
  keyword : String,
  flavor_prefix : Document,
  id : Document,
  name : BuslaneName,
) -> Document {
  flavor_prefix +
  text(keyword) +
  space +
  id +
  space +
  text("=") +
  space +
  name.pretty()
}

///|
fn type_declaration(id : TypeId, info : TypeInfo) -> Document {
  declaration_head(
    "type",
    external_prefix(info.flavor is External),
    id.pretty(),
    info.name,
  ) +
  type_parameters_doc(info.parameters) +
  space +
  braced_inline(info.constructors.map(DataConId::pretty)) +
  text(";")
}

///|
fn type_parameter_declaration(
  id : TypeParameterId,
  info : TypeParameterInfo,
) -> Document {
  declaration_head(
    "type_parameter",
    external_prefix(info.flavor is External),
    id.pretty(),
    info.name,
  ) +
  space +
  text(":") +
  space +
  info.kind.pretty() +
  text(";")
}

///|
fn value_declaration(id : ValueId, info : ValueInfo) -> Document {
  declaration_head("value", empty, id.pretty(), info.name) +
  space +
  info.kind.pretty() +
  space +
  text(":") +
  space +
  info.type_.pretty() +
  text(";")
}

///|
fn data_constructor_declaration(id : DataConId, info : DataConInfo) -> Document {
  declaration_head("datacon", empty, id.pretty(), info.name) +
  type_parameters_doc(info.hidden_type_parameters) +
  parenthesized_inline(info.payload_types.map(Type::pretty)) +
  space +
  text(":") +
  space +
  info.owner.pretty() +
  text(";")
}

///|
fn effect_declaration(id : EffectId, info : EffectInfo) -> Document {
  declaration_head(
    "effect",
    external_prefix(info.flavor is External),
    id.pretty(),
    info.name,
  ) +
  type_parameters_doc(info.parameters) +
  space +
  braced_inline(info.operations.map(OperationId::pretty)) +
  text(";")
}

///|
fn operation_declaration(id : OperationId, info : OperationInfo) -> Document {
  declaration_head("operation", empty, id.pretty(), info.name) +
  type_parameters_doc(info.hidden_type_parameters) +
  parenthesized_inline(info.payload_types.map(Type::pretty)) +
  space +
  text("->") +
  space +
  info.result_type.pretty() +
  space +
  text(":") +
  space +
  info.owner.pretty() +
  text(";")
}

///|
fn alternative_pattern_doc(alternative : Alternative) -> Document {
  match alternative.alt_constructor {
    Default => text("_")
    Literal(literal) => literal.pretty()
    DataCon(id) =>
      id.pretty() +
      type_parameters_doc(alternative.type_binders) +
      parenthesized_inline(alternative.value_binders.map(ValueId::pretty))
  }
}

///|
fn parenthesized_inline(docs : Array[Document]) -> Document {
  surround(char('('), char(')'), separate(text(",") + space, docs))
}

///|
fn bracketed_inline(docs : Array[Document]) -> Document {
  surround(char('['), char(']'), join_comma(docs))
}

///|
fn braced_inline(docs : Array[Document]) -> Document {
  surround(char('{'), char('}'), join_comma(docs))
}

///|
fn join_comma(docs : Array[Document]) -> Document {
  separate(text(",") + space, docs)
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

///|
/// The one place the `external` keyword is spelled. Type and effect flavors
/// are separate enums, so callers pass the predicate rather than the value.
fn external_prefix(is_external : Bool) -> Document {
  if is_external {
    text("external") + space
  } else {
    empty
  }
}
