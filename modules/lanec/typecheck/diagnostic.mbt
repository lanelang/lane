///|
using @compiler_diag {
  type CompilerDiagnostic,
  type CompilerDiagnosticFact,
  type CompilerDiagnosticLabel,
  type CompilerDiagnosticSeverity,
  type CompilerDiagnosticSuggestion,
  compiler_diagnostic,
  compiler_local_span,
  compiler_source_span,
}

///|
pub struct DisplayedTypeCheckDiagnostic {
  diagnostic : TypeCheckDiagnostic
  display : TypeDisplayContext
}

///|
pub fn TypeCheckDiagnostic::with_display(
  self : TypeCheckDiagnostic,
  display : TypeDisplayContext,
) -> DisplayedTypeCheckDiagnostic {
  { diagnostic: self, display }
}

///|
pub impl @compiler_diag.ToCompilerDiagnostic for DisplayedTypeCheckDiagnostic with fn to_compiler_diagnostic(
  self : DisplayedTypeCheckDiagnostic,
  context : @compiler_diag.DiagnosticContext,
) -> CompilerDiagnostic {
  let diagnostic = typecheck_diagnostic(self.diagnostic, self.display)
  match context.source_id {
    Some(source_id) => diagnostic.with_source_id(source_id)
    None => diagnostic
  }
}

///|
fn diagnostic(
  message : String,
  span~ : @basic.SourceSpan?,
  severity~ : CompilerDiagnosticSeverity,
  code~ : String?,
  labels~ : Array[CompilerDiagnosticLabel],
  notes~ : Array[String],
  helps~ : Array[String],
  facts? : Array[CompilerDiagnosticFact] = [],
  suggestions? : Array[CompilerDiagnosticSuggestion] = [],
) -> CompilerDiagnostic {
  compiler_diagnostic(
    message,
    span~,
    severity~,
    code~,
    labels~,
    notes~,
    helps~,
    facts~,
    suggestions~,
  )
}

///|
fn typecheck_diagnostic(
  diagnostic_ : TypeCheckDiagnostic,
  display : TypeDisplayContext,
) -> CompilerDiagnostic {
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
            span: compiler_local_span(diagnostic_.loc),
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
            span: compiler_local_span(diagnostic_.loc),
            message: "type checking could not resolve `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "this name survived resolution but has no usable value declaration",
        ],
        helps=["define the value or fix the import that should provide it"],
      )
    UnresolvedEffectOperation(name) =>
      diagnostic(
        "cannot find effect operation `\{name}`",
        span~,
        severity=Error,
        code=Some("E3015"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "no effect operation named `\{name}` is visible here",
            style: Primary,
          },
        ],
        notes=[
          "unqualified operation calls search the operation namespace, not ordinary values",
        ],
        helps=[
          "define the operation on an effect or call an existing operation with `Effect::\{name}!`",
        ],
      )
    AmbiguousEffectOperation(name~, candidates~) =>
      diagnostic(
        "ambiguous effect operation `\{name}`",
        span~,
        severity=Error,
        code=Some("E3014"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "this unqualified operation name matches multiple effects",
            style: Primary,
          },
        ],
        notes=[
          "candidates: " +
          candidates
          .map(fn(candidate) { display.operation_text(candidate) })
          .join(", "),
        ],
        helps=[
          "write the operation with an explicit effect owner, such as `Effect::\{name}!`",
        ],
      )
    MissingTopLevelLetAnnotation =>
      diagnostic(
        "top-level `let` needs a type annotation",
        span~,
        severity=Error,
        code=Some("E3002"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "this compilation boundary cannot infer a top-level `let` type",
            style: Primary,
          },
        ],
        notes=[
          "Lane requires top-level `let` declarations to state their interface type explicitly",
        ],
        helps=["write the declaration as `let name : Type = expression`"],
      )
    GenericArgumentArityMismatch(subject~, expected~, actual~) =>
      generic_argument_arity_diagnostic(
        diagnostic_, display, span, subject, expected, actual,
      )
    ApplicationArityMismatch(label~) =>
      application_arity_mismatch_diagnostic(diagnostic_, span, label)
    VariantReferenceFailure(label~) =>
      simple_typecheck_diagnostic(
        diagnostic_, span, "invalid variant reference", label, "check the variant name and enum owner",
      )
    InternalTypecheckFailure(label~) =>
      simple_typecheck_diagnostic(
        diagnostic_, span, "internal typecheck failure", label, "report this compiler bug with a minimal reproduction",
      )
    CallArityMismatch(expected~, actual~) =>
      call_arity_mismatch_diagnostic(diagnostic_, span, expected, actual)
    AutoParametersMustBeTrailing =>
      simple_typecheck_diagnostic(
        diagnostic_, span, "auto parameters must be trailing", "a non-auto parameter appears after an auto parameter",
        "move all auto parameters to the end of the parameter list",
      )
    AutoArgumentMustBeNamed =>
      simple_typecheck_diagnostic(
        diagnostic_, span, "auto argument must be named", "positional arguments cannot fill auto parameters",
        "pass the auto argument by name or let contextual offer insertion fill it",
      )
    DuplicateNamedArgument(name~) =>
      simple_typecheck_diagnostic(
        diagnostic_,
        span,
        "duplicate named argument `\{name}`",
        "`\{name}` was provided more than once",
        "remove the duplicate named argument",
      )
    UnknownContextualArgument(name~) =>
      simple_typecheck_diagnostic(
        diagnostic_,
        span,
        "unknown contextual argument `\{name}`",
        "no auto parameter named `\{name}` is available here",
        "check the argument name or remove it",
      )
    InvalidNamedArgument(name~) =>
      simple_typecheck_diagnostic(
        diagnostic_,
        span,
        "named argument `\{name}` is not accepted here",
        "this call position only accepts positional arguments",
        "remove the name or call a function with an auto parameter named `\{name}`",
      )
    InvalidNamedBuiltinArgument(name~) =>
      simple_typecheck_diagnostic(
        diagnostic_,
        span,
        "builtin call argument `\{name}` cannot be named",
        "`builtin` calls derive their parameter types from positional arguments",
        "remove the argument name",
      )
    MissingContextualOffer(expected~) =>
      contextual_offer_diagnostic(diagnostic_, display, span, expected, [])
    AmbiguousContextualOffer(expected~, candidates~) =>
      contextual_offer_diagnostic(
        diagnostic_, display, span, expected, candidates,
      )
    TypeAliasCycle(name~) =>
      diagnostic(
        "type alias `\{name}` is recursive",
        span~,
        severity=Error,
        code=Some("E3004"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
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
            span: compiler_local_span(diagnostic_.loc),
            message: "expected kind `\{display.kind_text(expected)}`, found `\{display.kind_text(actual)}`",
            style: Primary,
          },
        ],
        notes=[
          "`Type` is the kind of value-level types; function kinds such as `[Type] -> Type` describe type constructors",
        ],
        helps=[
          "add the intended kind annotation or apply the type constructor to enough generic arguments",
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
            span: compiler_local_span(diagnostic_.loc),
            message: "expected `\{display.type_text(expected)}`, found `\{display.type_text(actual)}`",
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
    EffectMismatch(expected~, actual~) =>
      diagnostic(
        "effect mismatch",
        span~,
        severity=Error,
        code=Some("E3007"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "expected effect `\{display.effect_text(expected)}`, found `\{display.effect_text(actual)}`",
            style: Primary,
          },
        ],
        notes=["Lane functions without an effect annotation are pure"],
        helps=[
          "add the required effect annotation or remove the effectful operation",
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
            span: compiler_local_span(diagnostic_.loc),
            message: "`\{display.type_text(type_)}` is not a function type",
            style: Primary,
          },
        ],
        notes=["only values with function type can be used in call position"],
        helps=["remove the call or use a function value here"],
      )
    GenericArgumentsOnNonGeneric(subject~, type_~) =>
      generic_arguments_on_non_generic_diagnostic(
        diagnostic_, display, span, subject, type_,
      )
    GenericArgumentInferenceFailed(label~, failure~) =>
      generic_argument_inference_failed_diagnostic(
        diagnostic_, display, span, label, failure,
      )
    UnknownField(name~) =>
      diagnostic(
        "unknown field `\{name}`",
        span~,
        severity=Error,
        code=Some("E3100"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
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
            span: compiler_local_span(diagnostic_.loc),
            message: "this struct construction or pattern omits required field `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "Lane struct literals and struct patterns must account for required fields",
        ],
        helps=["add a `\{name}: ...` field entry"],
        suggestions=[
          {
            message: "add a `\{name}: ...` field entry",
            edits: [],
            applicability: HasPlaceholders,
          },
        ],
      )
    DuplicateField(name~) =>
      diagnostic(
        "duplicate field `\{name}`",
        span~,
        severity=Error,
        code=Some("E3102"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "`\{name}` is provided more than once",
            style: Primary,
          },
        ],
        notes=["each struct field may appear at most once"],
        helps=["remove the duplicate field entry"],
        suggestions=[
          {
            message: "remove the duplicate field entry",
            edits: [
              { span: compiler_local_span(diagnostic_.loc), replacement: "" },
            ],
            applicability: MachineApplicable,
          },
        ],
      )
    UnknownTypeMember(name~) =>
      diagnostic(
        "unknown type member `\{name}`",
        span~,
        severity=Error,
        code=Some("E3103"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
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
            span: compiler_local_span(diagnostic_.loc),
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
            span: compiler_local_span(diagnostic_.loc),
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
            span: compiler_local_span(diagnostic_.loc),
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
            span: compiler_local_span(diagnostic_.loc),
            message: "`\{display.type_text(type_)}` is not a struct type",
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
    NonExhaustiveMatch(type_~, witness~) =>
      diagnostic(
        "non-exhaustive match",
        span~,
        severity=Error,
        code=Some("E3200"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "patterns do not cover every `\{display.type_text(type_)}` value",
            style: Primary,
          },
        ],
        notes=["Lane checks match coverage statically using the pattern matrix"],
        helps=non_exhaustive_match_helps(witness),
      )
    UnreachableMatchArm =>
      diagnostic(
        "unreachable match arm",
        span~,
        severity=Error,
        code=Some("E3201"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "this arm can never be selected",
            style: Primary,
          },
        ],
        notes=[
          "an earlier pattern already covers every value that would reach this arm",
        ],
        helps=["remove this arm or make the earlier patterns more specific"],
      )
    RefutablePatternLet(type_) =>
      diagnostic(
        "refutable pattern in `let` binding",
        span~,
        severity=Error,
        code=Some("E3205"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "this pattern may fail for some `\{display.type_text(type_)}` values",
            style: Primary,
          },
        ],
        notes=[
          "`let` pattern bindings must be irrefutable because there is no fallback branch",
          "struct patterns and single-variant enum patterns are allowed only when their nested patterns are also irrefutable",
        ],
        helps=[
          "use a `match` expression when the pattern can fail", "replace the refutable nested pattern with a binder and match it later",
        ],
      )
    MixedHandlerEffects =>
      diagnostic(
        "handler block mixes effects",
        span~,
        severity=Error,
        code=Some("E3202"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "all operation arms in one `with` block must belong to the same effect",
            style: Primary,
          },
        ],
        notes=["Lane handlers group operation alternatives by concrete effect"],
        helps=[
          "split operations from different effects into separate `with` blocks",
        ],
      )
    DuplicateHandledEffect(effect) =>
      diagnostic(
        "duplicate handled effect",
        span~,
        severity=Error,
        code=Some("E3203"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "this handler already has a `with` block for `\{display.effect_text(effect)}`",
            style: Primary,
          },
        ],
        notes=["a handler expression may handle each concrete effect once"],
        helps=["merge these operation arms into the existing `with` block"],
      )
    MissingHandlerOperation(operation) =>
      diagnostic(
        "missing handler operation",
        span~,
        severity=Error,
        code=Some("E3204"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "this handler does not cover operation `operation#\{operation.index}`",
            style: Primary,
          },
        ],
        notes=[
          "every operation declared by a handled effect must have exhaustive handler arms",
        ],
        helps=["add an arm for the missing operation"],
      )
    DuplicatePatternBinder(name~) =>
      diagnostic(
        "duplicate pattern binder `\{name}`",
        span~,
        severity=Error,
        code=Some("E3202"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
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
            span: compiler_local_span(diagnostic_.loc),
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
            span: compiler_local_span(diagnostic_.loc),
            message: "this expression exposes hidden type `\{display.type_text(type_)}` outside its unpacking scope",
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
            span: compiler_local_span(diagnostic_.loc),
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
    PrivateEffectEscape(name~) =>
      diagnostic(
        "private effect `\{name}` in public interface",
        span~,
        severity=Error,
        code=Some("E3109"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "public interface exposes private effect `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "downstream modules need public effect information to compile against this item",
        ],
        helps=[
          "make `\{name}` public or change the public effect alias to hide it",
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
            span: compiler_local_span(diagnostic_.loc),
            message: "`\{raw}` cannot be represented as a Lane `Int`",
            style: Primary,
          },
        ],
        notes=[
          "Lane `Int` literals must fit the compiler's supported integer range",
        ],
        helps=["use a smaller integer literal"],
      )
    InvalidDoubleLiteral(raw) =>
      diagnostic(
        "invalid double literal `\{raw}`",
        span~,
        severity=Error,
        code=Some("E3025"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "`\{raw}` cannot be represented as a finite Lane `Double`",
            style: Primary,
          },
        ],
        notes=[
          "Lane `Double` literals must parse to a finite IEEE 754 binary64 value",
        ],
        helps=["use a finite double literal within the binary64 range"],
      )
    BuiltinNeedsExpectedType(name~) =>
      diagnostic(
        "builtin `\{name}` needs an expected type",
        span~,
        severity=Error,
        code=Some("E3010"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "the result type of this builtin is unknown here",
            style: Primary,
          },
        ],
        notes=[
          "`builtin` is unsafe and opaque; Lane checks it only against an adjacent expected type",
        ],
        helps=[
          "add a type annotation to the binding, parameter, or surrounding expression",
        ],
        suggestions=[
          {
            message: "add an explicit type annotation near this builtin",
            edits: [],
            applicability: HasPlaceholders,
          },
        ],
      )
    FunctionLiteralParameterNeedsAnnotation(name~) => {
      let subject = match name {
        Some(name) => "parameter `\{name}`"
        None => "this parameter"
      }
      diagnostic(
        "function literal parameter needs a type annotation",
        span~,
        severity=Error,
        code=Some("E3010"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "\{subject} has no type annotation and no adjacent expected function type",
            style: Primary,
          },
        ],
        notes=[
          "Lane does not infer function literal parameter types without an expected function type",
        ],
        helps=["write the parameter as `name : Type`"],
      )
    }
    EmptyMatchNeedsExpectedType =>
      diagnostic(
        "empty match needs an expected result type",
        span~,
        severity=Error,
        code=Some("E3010"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "this match has no arms, so it cannot synthesize a result type",
            style: Primary,
          },
        ],
        notes=[
          "an empty match can only be checked when the surrounding expression already provides the result type",
        ],
        helps=[
          "add an expected type with a binding annotation or use the empty match where a result type is already known",
        ],
      )
    UnqualifiedVariantPatternNeedsExpectedEnum(variant~) =>
      diagnostic(
        "unqualified variant pattern `\{variant}` needs an expected enum type",
        span~,
        severity=Error,
        code=Some("E3010"),
        labels=[
          {
            span: compiler_local_span(diagnostic_.loc),
            message: "`\{variant}` cannot be resolved as a pattern without an enum scrutinee type",
            style: Primary,
          },
        ],
        notes=[
          "unqualified variant patterns are resolved from the matched value's enum type",
        ],
        helps=[
          "add a scrutinee type annotation or qualify the variant with its enum owner",
        ],
      )
  }
}

///|
fn generic_argument_arity_diagnostic(
  diagnostic_ : TypeCheckDiagnostic,
  display : TypeDisplayContext,
  span : @basic.SourceSpan?,
  subject : GenericArgumentSubject,
  expected : Int,
  actual : Int,
) -> CompilerDiagnostic {
  diagnostic(
    generic_argument_arity_title(subject),
    span~,
    severity=Error,
    code=Some("E3003"),
    labels=generic_argument_arity_labels(
      diagnostic_.loc,
      display,
      subject,
      expected,
      actual,
    ),
    notes=generic_argument_subject_notes(subject),
    helps=["add or remove generic arguments so the count is \{expected}"],
  )
}

///|
fn call_arity_mismatch_diagnostic(
  diagnostic_ : TypeCheckDiagnostic,
  span : @basic.SourceSpan?,
  expected : Int,
  actual : Int,
) -> CompilerDiagnostic {
  diagnostic(
    "wrong number of call arguments",
    span~,
    severity=Error,
    code=Some("E3012"),
    labels=[
      {
        span: compiler_local_span(diagnostic_.loc),
        message: "expected \{expected} argument(s), found \{actual}",
        style: Primary,
      },
    ],
    notes=[
      "function calls must provide exactly one argument for each non-contextual parameter",
    ],
    helps=["add or remove arguments so the call has \{expected} argument(s)"],
  )
}

///|
fn application_arity_mismatch_diagnostic(
  diagnostic_ : TypeCheckDiagnostic,
  span : @basic.SourceSpan?,
  label : String,
) -> CompilerDiagnostic {
  diagnostic(
    "wrong number of application arguments",
    span~,
    severity=Error,
    code=Some("E3012"),
    labels=[
      {
        span: compiler_local_span(diagnostic_.loc),
        message: label,
        style: Primary,
      },
    ],
    notes=["this application form was checked against a fixed parameter list"],
    helps=["check the number of value, type, or effect arguments"],
  )
}

///|
fn simple_typecheck_diagnostic(
  diagnostic_ : TypeCheckDiagnostic,
  span : @basic.SourceSpan?,
  title : String,
  label : String,
  help : String,
) -> CompilerDiagnostic {
  diagnostic(
    title,
    span~,
    severity=Error,
    code=Some("E3012"),
    labels=[
      {
        span: compiler_local_span(diagnostic_.loc),
        message: label,
        style: Primary,
      },
    ],
    notes=[],
    helps=[help],
  )
}

///|
fn contextual_offer_diagnostic(
  diagnostic_ : TypeCheckDiagnostic,
  display : TypeDisplayContext,
  span : @basic.SourceSpan?,
  expected : @types.Type,
  candidates : Array[ContextualOfferDiagnosticCandidate],
) -> CompilerDiagnostic {
  let expected_text = display.type_text(expected)
  if candidates.is_empty() {
    diagnostic(
      "missing contextual offer",
      span~,
      severity=Error,
      code=Some("E3013"),
      labels=[
        {
          span: compiler_local_span(diagnostic_.loc),
          message: "no visible offer matches required type `\{expected_text}`",
          style: Primary,
        },
      ],
      notes=[
        "contextual arguments are inserted only from visible `offer` bindings with matching type",
      ],
      helps=[
        "pass the argument explicitly or add a visible `offer` with type `\{expected_text}`",
      ],
    )
  } else {
    diagnostic(
      "ambiguous contextual offer",
      span~,
      severity=Error,
      code=Some("E3013"),
      labels=contextual_offer_labels(
        diagnostic_.loc,
        display,
        expected_text,
        candidates,
      ),
      notes=[
        "Lane will not choose between multiple matching contextual offers implicitly",
      ],
      helps=[
        "pass the argument explicitly or keep only one matching visible offer",
      ],
    )
  }
}

///|
fn contextual_offer_labels(
  loc : @basic.SourceSpan,
  display : TypeDisplayContext,
  expected_text : String,
  candidates : Array[ContextualOfferDiagnosticCandidate],
) -> Array[CompilerDiagnosticLabel] {
  let labels : Array[CompilerDiagnosticLabel] = [
    {
      span: compiler_local_span(loc),
      message: "\{candidates.length()} visible offers match required type `\{expected_text}`",
      style: Primary,
    },
  ]
  labels.append(contextual_offer_candidate_labels(display, candidates))
  labels
}

///|
fn contextual_offer_candidate_labels(
  display : TypeDisplayContext,
  candidates : Array[ContextualOfferDiagnosticCandidate],
) -> Array[CompilerDiagnosticLabel] {
  candidates.map(fn(candidate) {
    let span = match candidate.source_id {
      Some(source_id) => compiler_source_span(source_id, candidate.loc)
      None => compiler_local_span(candidate.loc)
    }
    {
      span,
      message: "candidate `\{candidate.name}` has type `\{display.type_text(candidate.type_)}`",
      style: Secondary,
    }
  })
}

///|
fn non_exhaustive_match_helps(witness : String?) -> Array[String] {
  match witness {
    Some(witness) =>
      [
        "add a pattern that covers `\{witness}`, or add a final `_` wildcard arm",
      ]
    None => ["add a missing constructor case or a final `_` wildcard arm"]
  }
}

///|
fn generic_arguments_on_non_generic_diagnostic(
  diagnostic_ : TypeCheckDiagnostic,
  display : TypeDisplayContext,
  span : @basic.SourceSpan?,
  subject : GenericArgumentSubject,
  type_ : @types.Type,
) -> CompilerDiagnostic {
  diagnostic(
    "generic arguments require a generic value",
    span~,
    severity=Error,
    code=Some("E3011"),
    labels=generic_arguments_on_non_generic_labels(
      diagnostic_.loc,
      display,
      subject,
      type_,
    ),
    notes=["explicit generic arguments instantiate values with `forall` type"],
    helps=["remove the generic arguments or make the callee generic"],
  )
}

///|
fn generic_argument_inference_failed_diagnostic(
  diagnostic_ : TypeCheckDiagnostic,
  display : TypeDisplayContext,
  span : @basic.SourceSpan?,
  label : String,
  failure : GenericArgumentInferenceFailure,
) -> CompilerDiagnostic {
  diagnostic(
    generic_argument_inference_title(label, failure),
    span~,
    severity=Error,
    code=Some(generic_argument_inference_code(failure)),
    labels=[
      {
        span: compiler_local_span(diagnostic_.loc),
        message: generic_argument_inference_primary_label(display, failure),
        style: Primary,
      },
    ],
    notes=generic_argument_inference_notes(failure),
    helps=[generic_argument_inference_help(label, failure)],
  )
}

///|
fn generic_argument_inference_notes(
  failure : GenericArgumentInferenceFailure,
) -> Array[String] {
  match failure {
    ConflictingGenericArgument(
      previous=TypeArgument(_),
      actual=TypeArgument(_),
      ..
    ) => ["Lane does not insert implicit conversions between different types"]
    ConflictingGenericArgument(
      previous=EffectArgument(_),
      actual=EffectArgument(_),
      ..
    ) => ["Lane functions without an effect annotation are pure"]
    _ =>
      [
        "Lane infers generic arguments only from the adjacent call arguments and expected result type",
      ]
  }
}

///|
fn generic_argument_inference_code(
  failure : GenericArgumentInferenceFailure,
) -> String {
  match failure {
    ConflictingGenericArgument(
      previous=TypeArgument(_),
      actual=TypeArgument(_),
      ..
    ) => "E3006"
    ConflictingGenericArgument(
      previous=EffectArgument(_),
      actual=EffectArgument(_),
      ..
    ) => "E3007"
    _ => "E3010"
  }
}

///|
fn generic_argument_arity_title(subject : GenericArgumentSubject) -> String {
  match subject {
    Named(name~) => "wrong number of generic arguments for `\{name}`"
    ExplicitExpression(callee=Some(callee), ..) =>
      "wrong number of explicit generic arguments for `\{callee}`"
    ExplicitExpression(callee=None, ..) =>
      "wrong number of explicit generic arguments"
  }
}

///|
fn generic_argument_inference_title(
  label : String,
  failure : GenericArgumentInferenceFailure,
) -> String {
  let subject = generic_argument_inference_subject(label)
  match failure {
    MissingGenericArguments(..) =>
      "cannot infer generic arguments for \{subject}"
    ConflictingGenericArgument(
      previous=TypeArgument(_),
      actual=TypeArgument(_),
      ..
    ) => "type mismatch"
    ConflictingGenericArgument(
      previous=EffectArgument(_),
      actual=EffectArgument(_),
      ..
    ) => "effect mismatch"
    ConflictingGenericArgument(..) =>
      "conflicting generic arguments for \{subject}"
    RecursiveGenericArgument(..) => "recursive generic argument for \{subject}"
    GenericArgumentConstraintMismatch(..) =>
      "generic argument constraint mismatch for \{subject}"
  }
}

///|
fn generic_argument_inference_subject(label : String) -> String {
  if label == "generic arguments" {
    "this call"
  } else if label.contains(" ") {
    label
  } else {
    "`\{label}`"
  }
}

///|
fn generic_argument_arity_labels(
  loc : @basic.SourceSpan,
  display : TypeDisplayContext,
  subject : GenericArgumentSubject,
  expected : Int,
  actual : Int,
) -> Array[CompilerDiagnosticLabel] {
  let labels : Array[CompilerDiagnosticLabel] = [
    {
      span: compiler_local_span(loc),
      message: generic_argument_arity_primary_label(subject, expected, actual),
      style: Primary,
    },
  ]
  add_generic_argument_subject_label(labels, display, subject, None)
  labels
}

///|
fn generic_argument_inference_primary_label(
  display : TypeDisplayContext,
  failure : GenericArgumentInferenceFailure,
) -> String {
  match failure {
    MissingGenericArguments(parameters~) =>
      "local context did not determine generic parameter(s) \{generic_parameter_list_text(parameters)}"
    ConflictingGenericArgument(
      previous=TypeArgument(expected),
      actual=TypeArgument(actual),
      ..
    ) =>
      "expected `\{display.type_text(expected)}`, found `\{display.type_text(actual)}`"
    ConflictingGenericArgument(
      previous=EffectArgument(expected),
      actual=EffectArgument(actual),
      ..
    ) =>
      "expected effect `\{display.effect_text(expected)}`, found `\{display.effect_text(actual)}`"
    ConflictingGenericArgument(parameter~, previous~, actual~) =>
      "generic parameter `\{parameter.name}` was inferred as `\{display.generic_argument_text(previous)}` and `\{display.generic_argument_text(actual)}`"
    RecursiveGenericArgument(parameter~, actual~) =>
      "generic parameter `\{parameter.name}` would recursively contain `\{display.generic_argument_text(actual)}`"
    GenericArgumentConstraintMismatch(expected~, actual~) =>
      "generic inference expected `\{display.generic_argument_text(expected)}`, found `\{display.generic_argument_text(actual)}`"
  }
}

///|
fn generic_argument_inference_help(
  label : String,
  failure : GenericArgumentInferenceFailure,
) -> String {
  let subject = generic_argument_inference_subject(label)
  match failure {
    MissingGenericArguments(..) =>
      "add explicit generic arguments for \{subject} or provide an expected result type"
    ConflictingGenericArgument(
      previous=TypeArgument(_),
      actual=TypeArgument(_),
      ..
    ) =>
      "make this argument agree with the type inferred earlier, or pass explicit generic arguments"
    ConflictingGenericArgument(
      previous=EffectArgument(_),
      actual=EffectArgument(_),
      ..
    ) =>
      "make this effect agree with the effect inferred earlier, or pass explicit generic arguments"
    ConflictingGenericArgument(parameter~, ..) =>
      "make every use of generic parameter `\{parameter.name}` agree, or pass explicit generic arguments"
    RecursiveGenericArgument(parameter~, ..) =>
      "remove the recursive effect constraint involving `\{parameter.name}`"
    GenericArgumentConstraintMismatch(..) =>
      "adjust the argument or expected result type so the generic constraints match"
  }
}

///|
fn generic_parameter_list_text(
  parameters : Array[@types.TypeParameter],
) -> String {
  if parameters.is_empty() {
    "<unknown>"
  } else {
    parameters.map(fn(parameter) { "`\{parameter.name}`" }).join(", ")
  }
}

///|
fn generic_argument_arity_primary_label(
  subject : GenericArgumentSubject,
  expected : Int,
  actual : Int,
) -> String {
  match subject {
    Named(name~) =>
      "`\{name}` expects \{expected} generic argument(s), but \{actual} were provided"
    ExplicitExpression(..) =>
      "this explicit generic argument list provides \{actual} argument(s), but the callee expects \{expected}"
  }
}

///|
fn generic_arguments_on_non_generic_labels(
  loc : @basic.SourceSpan,
  display : TypeDisplayContext,
  subject : GenericArgumentSubject,
  type_ : @types.Type,
) -> Array[CompilerDiagnosticLabel] {
  let labels : Array[CompilerDiagnosticLabel] = [
    {
      span: compiler_local_span(loc),
      message: generic_arguments_on_non_generic_primary_label(
        display, subject, type_,
      ),
      style: Primary,
    },
  ]
  add_generic_argument_subject_label(labels, display, subject, Some(type_))
  labels
}

///|
fn generic_arguments_on_non_generic_primary_label(
  display : TypeDisplayContext,
  subject : GenericArgumentSubject,
  type_ : @types.Type,
) -> String {
  match subject {
    Named(_) => "`\{display.type_text(type_)}` is not a generic function type"
    ExplicitExpression(..) =>
      "these explicit generic arguments require a value with `forall` type"
  }
}

///|
fn add_generic_argument_subject_label(
  labels : Array[CompilerDiagnosticLabel],
  display : TypeDisplayContext,
  subject : GenericArgumentSubject,
  type_ : @types.Type?,
) -> Unit {
  if subject is ExplicitExpression(callee=Some(callee), callee_loc=Some(loc)) {
    let message = match type_ {
      Some(type_) => "`\{callee}` has type `\{display.type_text(type_)}`"
      None => "generic callee `\{callee}`"
    }
    labels.push({ span: compiler_local_span(loc), message, style: Secondary })
  }
}

///|
fn generic_argument_subject_notes(
  subject : GenericArgumentSubject,
) -> Array[String] {
  match subject {
    Named(_) =>
      [
        "type constructors, effects, variants, and generic functions must be applied with their declared arity",
      ]
    ExplicitExpression(..) =>
      ["explicit generic arguments instantiate values with `forall` type"]
  }
}
