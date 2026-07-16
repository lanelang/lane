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
pub impl @prettyprinter.Pretty for BuslaneName with fn pretty(
  name : BuslaneName,
) {
  text("\{name.occurrence}#\{name.unique.value}")
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
    Int => text("Int")
    Double => text("Double")
    String => text("String")
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
pub impl @prettyprinter.Pretty for GenericArgument with fn pretty(
  argument : GenericArgument,
) {
  match argument {
    TypeArgument(type_) => type_.pretty()
    EffectArgument(effect) => effect.pretty()
  }
}

///|
pub impl @prettyprinter.Pretty for Literal with fn pretty(literal : Literal) {
  match literal {
    Unit => text("()")
    Bool(value) => text(value.to_string())
    Int(value) => text(value.to_string())
    Double(value) => text(value.to_string())
    String(value) => quoted(value)
  }
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
  (if info.flavor is External {
    text("external") + space + text("type")
  } else {
    text("type")
  }) +
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
  (if info.flavor is External {
    text("external") + space + text("effect")
  } else {
    text("effect")
  }) +
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
  diagnostic.kind.pretty()
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
fn function_type_doc(
  parameters : Array[Type],
  result : Type,
  effect : Effect,
) -> Document {
  let base = parenthesized_inline(parameters.map(Type::pretty)) +
    space +
    text("->") +
    space +
    result.pretty()
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
fn metadata_declarations(metadata : MetadataRegistry) -> Array[Document] {
  let declarations : Array[Document] = []
  for index in 0..<metadata.types.length() {
    declarations.push(
      type_declaration(metadata, { index, }, metadata.types[index]),
    )
  }
  for index in 0..<metadata.type_parameters.length() {
    declarations.push(
      type_parameter_declaration({ index, }, metadata.type_parameters[index]),
    )
  }
  for index in 0..<metadata.values.length() {
    declarations.push(value_declaration({ index, }, metadata.values[index]))
  }
  for index in 0..<metadata.effects.length() {
    declarations.push(
      effect_declaration(metadata, { index, }, metadata.effects[index]),
    )
  }
  declarations
}

///|
fn type_declaration(
  metadata : MetadataRegistry,
  _id : TypeId,
  info : TypeInfo,
) -> Document {
  (if info.flavor is External {
    text("external") + space + text("type")
  } else {
    text("type")
  }) +
  space +
  info.name.pretty() +
  type_parameters_doc(info.parameters) +
  space +
  braced_block(
    info.constructors.map(fn(data_constructor) {
      match metadata.data_constructor_info(data_constructor) {
        Some(info) => data_constructor_declaration(data_constructor, info)
        None => data_constructor.pretty()
      }
    }),
  )
}

///|
fn type_parameter_declaration(
  _id : TypeParameterId,
  info : TypeParameterInfo,
) -> Document {
  text("type_parameter") +
  space +
  info.name.pretty() +
  space +
  text(":") +
  space +
  info.kind.pretty()
}

///|
fn value_declaration(_id : ValueId, info : ValueInfo) -> Document {
  info.kind.pretty() +
  space +
  info.name.pretty() +
  space +
  text(":") +
  space +
  info.type_.pretty()
}

///|
fn data_constructor_declaration(
  _id : DataConId,
  info : DataConInfo,
) -> Document {
  info.name.pretty() +
  type_parameters_doc(info.hidden_type_parameters) +
  parenthesized_inline(info.payload_types.map(Type::pretty))
}

///|
fn effect_declaration(
  metadata : MetadataRegistry,
  _id : EffectId,
  info : EffectInfo,
) -> Document {
  (if info.flavor is External {
    text("external") + space + text("effect")
  } else {
    text("effect")
  }) +
  space +
  info.name.pretty() +
  type_parameters_doc(info.parameters) +
  space +
  braced_block(
    info.operations.map(fn(operation) {
      match metadata.operation_info(operation) {
        Some(info) => operation_declaration(operation, info)
        None => operation.pretty()
      }
    }),
  )
}

///|
fn operation_declaration(_id : OperationId, info : OperationInfo) -> Document {
  info.name.pretty() +
  type_parameters_doc(info.hidden_type_parameters) +
  parenthesized_inline(info.payload_types.map(Type::pretty)) +
  space +
  text("->") +
  space +
  info.result_type.pretty()
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
