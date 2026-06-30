///|
using @prettyprinter {type Document, line, separate, space, text}

///|
pub(all) struct CompileDiagnostic {
  message : String
  span : @basic.SourceSpan?
  severity : CompileDiagnosticSeverity
  code : String?
  labels : Array[CompileDiagnosticLabel]
  notes : Array[String]
  helps : Array[String]
} derive(Debug, Eq)

///|
pub(all) enum CompileDiagnosticSeverity {
  Error
  Warning
} derive(Debug, Eq)

///|
pub(all) struct CompileDiagnosticLabel {
  span : @basic.SourceSpan
  message : String
  style : CompileDiagnosticLabelStyle
} derive(Debug, Eq)

///|
pub(all) enum CompileDiagnosticLabelStyle {
  Primary
  Secondary
} derive(Debug, Eq)

///|
fn make_error(
  message : String,
  span~ : @basic.SourceSpan?,
) -> CompileDiagnostic {
  diagnostic(
    message,
    span~,
    severity=Error,
    code=None,
    labels=primary_label(span, message),
    notes=[],
    helps=[],
  )
}

///|
fn diagnostic(
  message : String,
  span~ : @basic.SourceSpan?,
  severity~ : CompileDiagnosticSeverity,
  code~ : String?,
  labels~ : Array[CompileDiagnosticLabel],
  notes~ : Array[String],
  helps~ : Array[String],
) -> CompileDiagnostic {
  { message, span, severity, code, labels, notes, helps }
}

///|
fn primary_label(
  span : @basic.SourceSpan?,
  message : String,
) -> Array[CompileDiagnosticLabel] {
  match span {
    Some(span) => [{ span, message, style: Primary }]
    None => []
  }
}

///|
fn parse_diagnostics(result : @parser.ParseResult) -> Array[CompileDiagnostic] {
  let diagnostics = []
  for error in result.lexical_errors {
    diagnostics.push(lex_diagnostic(error))
  }
  for error in result.parse_errors {
    diagnostics.push(parse_diagnostic(error))
  }
  diagnostics
}

///|
fn resolve_diagnostic(
  diagnostic_ : @resolve.ResolveDiagnostic,
) -> CompileDiagnostic {
  let span = Some(diagnostic_.loc)
  match diagnostic_.kind {
    UnresolvedType(name) =>
      diagnostic(
        "cannot find type `\{name}`",
        span~,
        severity=Error,
        code=Some("E2000"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "no type named `\{name}` is visible here",
            style: Primary,
          },
        ],
        notes=[
          "Lane resolves type names from the current module and explicitly imported public types",
        ],
        helps=[
          "declare `\{name}`, import the module that exports it, or qualify the type as `Module.\{name}`",
        ],
      )
    UnresolvedValue(name) =>
      diagnostic(
        "cannot find value `\{name}`",
        span~,
        severity=Error,
        code=Some("E2001"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "no value named `\{name}` is visible here",
            style: Primary,
          },
        ],
        notes=[
          "Lane value lookup uses local bindings, top-level values, and explicitly imported public values",
        ],
        helps=[
          "define `\{name}` before this use, import it, or qualify it with its module path",
        ],
      )
    UnresolvedField(type_name~, field~) =>
      diagnostic(
        "cannot find field `\{field}` on `\{type_name}`",
        span~,
        severity=Error,
        code=Some("E2002"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{type_name}` has no visible field named `\{field}`",
            style: Primary,
          },
        ],
        notes=[
          "field lookup only sees fields declared by the resolved struct type",
        ],
        helps=[
          "check the field spelling or change the expression to a struct type that declares `\{field}`",
        ],
      )
    UnresolvedQualifiedVariant(type_name~, variant~) =>
      diagnostic(
        "cannot find variant `\{type_name}::\{variant}`",
        span~,
        severity=Error,
        code=Some("E2003"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this enum type does not expose a variant named `\{variant}`",
            style: Primary,
          },
        ],
        notes=[
          "qualified variant lookup first resolves the enum type, then its variants",
        ],
        helps=[
          "check the variant spelling or use a variant declared by `\{type_name}`",
        ],
      )
    PayloadlessVariantCall(name) =>
      diagnostic(
        "payloadless variant `\{name}` is not callable",
        span~,
        severity=Error,
        code=Some("E2004"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` has no payload, so it is already a value",
            style: Primary,
          },
        ],
        notes=["only variants with payload fields are called with arguments"],
        helps=["remove the call syntax and use `\{name}` directly"],
      )
    ConflictingTopLevelValue(name~, existing~, incoming~) =>
      diagnostic(
        "conflicting top-level value `\{name}`",
        span~,
        severity=Error,
        code=Some("E2005"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{incoming}` conflicts with an existing value named `\{existing}`",
            style: Primary,
          },
        ],
        notes=["a Lane module has one top-level value namespace"],
        helps=["rename one of the declarations or remove the duplicate import"],
      )
    AmbiguousModuleValue(name) =>
      diagnostic(
        "ambiguous module-qualified value `\{name}`",
        span~,
        severity=Error,
        code=Some("E2006"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` can refer to more than one imported value",
            style: Primary,
          },
        ],
        notes=[
          "Lane does not choose between ambiguous imports because doing so would make name resolution order-dependent",
        ],
        helps=[
          "import only one matching module or use a more specific module path before the value name",
        ],
      )
    AmbiguousUnqualifiedVariant(name~, candidates~) =>
      diagnostic(
        "ambiguous variant `\{name}`",
        span~,
        severity=Error,
        code=Some("E2007"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` matches more than one visible enum variant",
            style: Primary,
          },
        ],
        notes=["candidates: " + resolve_variant_candidates_text(candidates)],
        helps=[
          "qualify the variant with its enum type, for example `Enum::\{name}`",
        ],
      )
  }
}

///|
fn resolve_variant_candidates_text(
  candidates : Array[@resolve.ResolveVariantCandidate],
) -> String {
  candidates
  .map(fn(candidate) { candidate.owner + "::" + candidate.variant })
  .join(", ")
}

///|
fn typecheck_diagnostic(
  diagnostic_ : @typecheck.TypeCheckDiagnostic,
) -> CompileDiagnostic {
  let span = Some(diagnostic_.loc)
  match diagnostic_.kind {
    UnresolvedType(name) =>
      diagnostic(
        "cannot find type `\{name}`",
        span~,
        severity=Error,
        code=Some("E3000"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "type checking could not resolve `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "this name survived resolution but has no usable type declaration",
        ],
        helps=["declare the type or fix the import that should provide it"],
      )
    UnresolvedValue(name) =>
      diagnostic(
        "cannot find value `\{name}`",
        span~,
        severity=Error,
        code=Some("E3001"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "type checking could not resolve `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "this name survived resolution but has no usable value declaration",
        ],
        helps=["define the value or fix the import that should provide it"],
      )
    MissingTopLevelLetAnnotation =>
      diagnostic(
        "top-level `let` needs a type annotation",
        span~,
        severity=Error,
        code=Some("E3002"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this compilation boundary cannot infer a top-level `let` type",
            style: Primary,
          },
        ],
        notes=[
          "Lane requires top-level `let` declarations to state their interface type explicitly",
        ],
        helps=["write the declaration as `let name : Type = expression`"],
      )
    TypeArgumentArityMismatch(name~, expected~, actual~) =>
      diagnostic(
        "wrong number of type arguments for `\{name}`",
        span~,
        severity=Error,
        code=Some("E3003"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` expects \{expected} type argument(s), but \{actual} were provided",
            style: Primary,
          },
        ],
        notes=[
          "type constructors and generic functions must be applied with their declared arity",
        ],
        helps=["add or remove type arguments so the count is \{expected}"],
      )
    TypeAliasCycle(name~) =>
      diagnostic(
        "type alias `\{name}` is recursive",
        span~,
        severity=Error,
        code=Some("E3004"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` expands back to itself",
            style: Primary,
          },
        ],
        notes=["Lane type aliases must be finite expansions"],
        helps=["break the cycle by introducing a nominal `struct` or `enum`"],
      )
    KindMismatch(expected~, actual~) =>
      diagnostic(
        "kind mismatch",
        span~,
        severity=Error,
        code=Some("E3005"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "expected kind `\{diagnostic_kind_text(expected)}`, found `\{diagnostic_kind_text(actual)}`",
            style: Primary,
          },
        ],
        notes=[
          "`Type` is the kind of value-level types; function kinds such as `[Type] -> Type` describe type constructors",
        ],
        helps=[
          "add the intended kind annotation or apply the type constructor to enough type arguments",
        ],
      )
    TypeMismatch(expected~, actual~) =>
      diagnostic(
        "type mismatch",
        span~,
        severity=Error,
        code=Some("E3006"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "expected `\{diagnostic_type_text(expected)}`, found `\{diagnostic_type_text(actual)}`",
            style: Primary,
          },
        ],
        notes=[
          "Lane does not insert implicit conversions between different types",
        ],
        helps=[
          "change the expression type or adjust the annotation/expected type",
        ],
      )
    NotCallable(type_) =>
      diagnostic(
        "value is not callable",
        span~,
        severity=Error,
        code=Some("E3007"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{diagnostic_type_text(type_)}` is not a function type",
            style: Primary,
          },
        ],
        notes=["only values with function type can be used in call position"],
        helps=["remove the call or use a function value here"],
      )
    UnknownField(name~) =>
      diagnostic(
        "unknown field `\{name}`",
        span~,
        severity=Error,
        code=Some("E3100"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this struct does not have a visible field named `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "field names are checked against the resolved struct declaration",
        ],
        helps=["check the field spelling or update the struct declaration"],
      )
    MissingField(name~) =>
      diagnostic(
        "missing field `\{name}`",
        span~,
        severity=Error,
        code=Some("E3101"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this struct construction or pattern omits required field `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "Lane struct literals and struct patterns must account for required fields",
        ],
        helps=["add a `\{name}: ...` field entry"],
      )
    DuplicateField(name~) =>
      diagnostic(
        "duplicate field `\{name}`",
        span~,
        severity=Error,
        code=Some("E3102"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` is provided more than once",
            style: Primary,
          },
        ],
        notes=["each struct field may appear at most once"],
        helps=["remove the duplicate field entry"],
      )
    UnknownTypeMember(name~) =>
      diagnostic(
        "unknown type member `\{name}`",
        span~,
        severity=Error,
        code=Some("E3103"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this existential struct has no visible type member named `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "type members are checked against the resolved struct declaration",
        ],
        helps=[
          "check the type member spelling or update the struct declaration",
        ],
      )
    MissingTypeMember(name~) =>
      diagnostic(
        "missing type member `\{name}`",
        span~,
        severity=Error,
        code=Some("E3104"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this existential struct value omits required type member `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "existential struct construction must provide witnesses for required type members",
        ],
        helps=["add a `type \{name} = ...` member entry"],
      )
    DuplicateTypeMember(name~) =>
      diagnostic(
        "duplicate type member `\{name}`",
        span~,
        severity=Error,
        code=Some("E3105"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` is provided more than once",
            style: Primary,
          },
        ],
        notes=["each type member may appear at most once"],
        helps=["remove the duplicate type member entry"],
      )
    DuplicateTypeParameter(name~) =>
      diagnostic(
        "duplicate type parameter `\{name}`",
        span~,
        severity=Error,
        code=Some("E3106"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` is bound more than once in the same parameter list",
            style: Primary,
          },
        ],
        notes=[
          "duplicate type parameter binders would make references ambiguous",
        ],
        helps=["rename one of the type parameters"],
      )
    NotAStruct(type_) =>
      diagnostic(
        "expected a struct type",
        span~,
        severity=Error,
        code=Some("E3008"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{diagnostic_type_text(type_)}` is not a struct type",
            style: Primary,
          },
        ],
        notes=[
          "field access, struct literals, and struct patterns require a struct type",
        ],
        helps=[
          "use a struct value here or change the surrounding type annotation",
        ],
      )
    NonExhaustiveMatch(type_) =>
      diagnostic(
        "non-exhaustive match",
        span~,
        severity=Error,
        code=Some("E3200"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "patterns do not cover every `\{diagnostic_type_text(type_)}` value",
            style: Primary,
          },
        ],
        notes=["Lane checks match coverage statically using the pattern matrix"],
        helps=["add a missing constructor case or a final `_` wildcard arm"],
      )
    UnreachableMatchArm =>
      diagnostic(
        "unreachable match arm",
        span~,
        severity=Error,
        code=Some("E3201"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this arm can never be selected",
            style: Primary,
          },
        ],
        notes=[
          "an earlier pattern already covers every value that would reach this arm",
        ],
        helps=["remove this arm or make the earlier patterns more specific"],
      )
    DuplicatePatternBinder(name~) =>
      diagnostic(
        "duplicate pattern binder `\{name}`",
        span~,
        severity=Error,
        code=Some("E3202"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` is bound more than once in the same pattern",
            style: Primary,
          },
        ],
        notes=[
          "Lane patterns do not use repeated names as equality constraints",
        ],
        helps=["rename one binder or match the second position with `_`"],
      )
    PatternArityMismatch(name~, expected~, actual~) =>
      diagnostic(
        "wrong number of fields for pattern `\{name}`",
        span~,
        severity=Error,
        code=Some("E3203"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` expects \{expected} payload field(s), but \{actual} were provided",
            style: Primary,
          },
        ],
        notes=["constructor patterns must match the variant payload arity"],
        helps=["add or remove pattern arguments so the count is \{expected}"],
      )
    HiddenTypeEscape(type_~) =>
      diagnostic(
        "hidden existential type escapes its scope",
        span~,
        severity=Error,
        code=Some("E3107"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this expression exposes hidden type `\{diagnostic_type_text(type_)}` outside its unpacking scope",
            style: Primary,
          },
        ],
        notes=[
          "existential witnesses must remain abstract outside the packed value",
        ],
        helps=["return a value whose type does not mention the hidden witness"],
      )
    PrivateTypeEscape(name~) =>
      diagnostic(
        "private type `\{name}` in public interface",
        span~,
        severity=Error,
        code=Some("E3108"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "public interface exposes private type `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "downstream modules need public type information to compile against this item",
        ],
        helps=[
          "make `\{name}` public or change the public signature to hide it",
        ],
      )
    InvalidIntLiteral(raw) =>
      diagnostic(
        "invalid integer literal `\{raw}`",
        span~,
        severity=Error,
        code=Some("E3009"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{raw}` cannot be represented as a Lane `Int`",
            style: Primary,
          },
        ],
        notes=[
          "Lane `Int` literals must fit the compiler's supported integer range",
        ],
        helps=["use a smaller integer literal"],
      )
    CannotInferExpression(label) =>
      diagnostic(
        "cannot infer expression type",
        span~,
        severity=Error,
        code=Some("E3010"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "the checker needs more type information for `\{label}`",
            style: Primary,
          },
        ],
        notes=[
          "this diagnostic is emitted when local context is not enough to choose a unique type",
        ],
        helps=[cannot_infer_help(label)],
      )
  }
}

///|
fn diagnostic_type_text(type_ : @types.Type) -> String {
  @prettyprinter.render(type_, width=100)
}

///|
fn diagnostic_kind_text(kind : @types.Kind) -> String {
  @prettyprinter.render(kind, width=100)
}

///|
fn cannot_infer_help(label : String) -> String {
  if label.contains("contextual offer") {
    "add a visible `offer` with the required type or pass the contextual argument explicitly"
  } else if label.contains("function literal parameter") {
    "add an explicit parameter type annotation to the function literal"
  } else if label.contains("call arity") || label.contains("arity") {
    "check the number of arguments and type arguments at this call site"
  } else if label.contains("type arguments") {
    "add explicit type arguments or provide an expected result type"
  } else if label.contains("builtin") {
    "add a type annotation so the builtin can be checked against a concrete function type"
  } else {
    "add a type annotation near this expression"
  }
}

///|
fn lex_diagnostic(error : @lexer.LexError) -> CompileDiagnostic {
  let span = Some(error.span)
  diagnostic(
    lex_error_title(error.error),
    span~,
    severity=Error,
    code=Some(lex_error_code(error.error)),
    labels=[
      {
        span: error.span,
        message: lex_error_label(error.error),
        style: Primary,
      },
    ],
    notes=lex_error_notes(error.error),
    helps=lex_error_helps(error.error),
  )
}

///|
fn lex_error_code(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(_) => "E1000"
    UnterminatedBlockComment => "E1001"
    UnterminatedString => "E1002"
    InvalidStringEscape(_) => "E1003"
    InvalidHexEscape(_) => "E1004"
    NonAsciiStringCharacter => "E1005"
  }
}

///|
fn lex_error_title(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(_) => "illegal character in source"
    UnterminatedBlockComment => "unterminated block comment"
    UnterminatedString => "unterminated string literal"
    InvalidStringEscape(_) => "invalid string escape"
    InvalidHexEscape(_) => "invalid hexadecimal escape"
    NonAsciiStringCharacter => "non-ASCII character in string literal"
  }
}

///|
fn lex_error_label(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(value) => "`\{value}` is not valid Lane syntax"
    UnterminatedBlockComment => "this block comment is never closed"
    UnterminatedString => "this string literal is never closed"
    InvalidStringEscape(value) =>
      "`\{value}` is not a supported escape sequence"
    InvalidHexEscape(value) => "`\{value}` is not a valid hexadecimal escape"
    NonAsciiStringCharacter =>
      "Lane string literals currently accept ASCII characters only"
  }
}

///|
fn lex_error_notes(error : @lexer.LexicalError) -> Array[String] {
  match error {
    NonAsciiStringCharacter =>
      [
        "the lexer rejects non-ASCII bytes inside string literals in the current language version",
      ]
    _ => []
  }
}

///|
fn lex_error_helps(error : @lexer.LexicalError) -> Array[String] {
  match error {
    IllegalCharacter(_) =>
      ["remove this character or replace it with a valid Lane token"]
    UnterminatedBlockComment => ["add a closing `*/` before the end of file"]
    UnterminatedString => ["add a closing `\"` before the end of the line"]
    InvalidStringEscape(_) =>
      ["use a supported escape such as `\\n`, `\\t`, `\\\"`, or `\\\\`"]
    InvalidHexEscape(_) =>
      ["write hexadecimal escapes with exactly two hexadecimal digits"]
    NonAsciiStringCharacter =>
      ["replace the character with ASCII text or an explicit supported escape"]
  }
}

///|
fn parse_diagnostic(error : @parser.ParseError) -> CompileDiagnostic {
  let span = Some(error.loc)
  diagnostic(
    parse_error_title(error.kind),
    span~,
    severity=Error,
    code=Some(parse_error_code(error.kind)),
    labels=[
      {
        span: error.loc,
        message: parse_error_label(error.kind),
        style: Primary,
      },
    ],
    notes=parse_error_notes(error.kind),
    helps=parse_error_helps(error.kind),
  )
}

///|
fn parse_error_code(error : @parser.ParseErrorKind) -> String {
  match error {
    UnexpectedToken(_, _) => "E1100"
    UnexpectedEndOfInput(_) => "E1101"
  }
}

///|
fn parse_error_title(error : @parser.ParseErrorKind) -> String {
  match error {
    UnexpectedToken(_, _) => "unexpected token"
    UnexpectedEndOfInput(_) => "unexpected end of input"
  }
}

///|
fn parse_error_label(error : @parser.ParseErrorKind) -> String {
  match error {
    UnexpectedToken(token, _) => "the parser did not expect " + token.label
    UnexpectedEndOfInput(_) =>
      "the source file ended while parsing this construct"
  }
}

///|
fn parse_error_notes(error : @parser.ParseErrorKind) -> Array[String] {
  match error {
    UnexpectedToken(_, expected) | UnexpectedEndOfInput(expected) =>
      if expected.is_empty() {
        []
      } else {
        ["expected one of: " + expected_list(expected)]
      }
  }
}

///|
fn parse_error_helps(error : @parser.ParseErrorKind) -> Array[String] {
  match error {
    UnexpectedToken(_, expected) =>
      if expected.is_empty() {
        ["remove the unexpected token or rewrite the surrounding expression"]
      } else {
        [
          "rewrite this position so it starts with one of: " +
          expected_list(expected),
        ]
      }
    UnexpectedEndOfInput(expected) =>
      if expected.is_empty() {
        ["finish the incomplete construct before the end of file"]
      } else {
        [
          "add the missing syntax before the end of file; expected one of: " +
          expected_list(expected),
        ]
      }
  }
}

///|
fn expected_list(expected : Array[@parser.ExpectedSyntax]) -> String {
  expected.map(fn(item) { item.label }).join(", ")
}

///|
fn span_text(span : @basic.SourceSpan) -> String {
  span.start_line.to_string() +
  ":" +
  span.start_column.to_string() +
  "-" +
  span.end_line.to_string() +
  ":" +
  span.end_column.to_string()
}

///|
pub impl @prettyprinter.Pretty for CompileDiagnostic with fn pretty(
  diagnostic : CompileDiagnostic,
) -> Document {
  let header = severity_doc(diagnostic.severity) +
    code_doc(diagnostic.code) +
    text(":") +
    space +
    text(diagnostic.message)
  let body = diagnostic_body_doc(diagnostic)
  if body is Some(body) {
    header + line + body
  } else {
    header
  }
}

///|
fn severity_doc(severity : CompileDiagnosticSeverity) -> Document {
  match severity {
    Error => text("error")
    Warning => text("warning")
  }
}

///|
fn code_doc(code : String?) -> Document {
  match code {
    Some(code) => text("[") + text(code) + text("]")
    None => text("")
  }
}

///|
fn diagnostic_body_doc(diagnostic : CompileDiagnostic) -> Document? {
  let docs : Array[Document] = []
  match diagnostic.span {
    Some(span) => docs.push(text("  -->") + space + text(span_text(span)))
    None => ()
  }
  for label in diagnostic.labels {
    docs.push(label_doc(label))
  }
  for note in diagnostic.notes {
    docs.push(text("  = note:") + space + text(note))
  }
  for help in diagnostic.helps {
    docs.push(text("  = help:") + space + text(help))
  }
  if docs.is_empty() {
    None
  } else {
    Some(separate(line, docs))
  }
}

///|
fn label_doc(label : CompileDiagnosticLabel) -> Document {
  let prefix = match label.style {
    Primary => text("  = label:")
    Secondary => text("  = note:")
  }
  prefix + space + text(span_text(label.span)) + space + text(label.message)
}

///|
pub impl @prettyprinter.Pretty for CheckResult with fn pretty(
  result : CheckResult,
) -> Document {
  diagnostics_doc(result.diagnostics)
}

///|
pub impl @prettyprinter.Pretty for CompileResult with fn pretty(
  result : CompileResult,
) -> Document {
  diagnostics_doc(result.diagnostics)
}

///|
fn diagnostics_doc(diagnostics : Array[CompileDiagnostic]) -> Document {
  if diagnostics.is_empty() {
    text("diagnostics") + space + text("{}")
  } else {
    text("diagnostics") +
    space +
    separate(line, diagnostics.map(CompileDiagnostic::pretty))
  }
}
