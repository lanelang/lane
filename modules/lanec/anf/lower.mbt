///|
priv struct AnfLowerer {
  mut next_temp : Int
}

///|
/// Lowers Checked Source into ANF.
pub fn lower_checked_source_file_to_anf(
  source : @checked.CheckedSourceFile,
) -> AnfProgram {
  let lowerer = AnfLowerer::{ next_temp: 0 }
  {
    declarations: source.declarations.map(fn(declaration) {
      lowerer.lower_top_level_declaration(declaration)
    }),
    loc: source.loc,
  }
}

///|
fn AnfLowerer::fresh_temp(self : AnfLowerer) -> AnfTempId {
  let temp = AnfTempId::{ index: self.next_temp }
  self.next_temp = self.next_temp + 1
  temp
}

///|
fn AnfLowerer::lower_top_level_declaration(
  self : AnfLowerer,
  declaration : @checked.CheckedTopLevelDeclaration,
) -> AnfTopLevelDeclaration {
  match declaration {
    Struct(declaration) => Struct(declaration)
    Enum(declaration) => Enum(declaration)
    Effect(declaration) => Effect(declaration)
    Function(declaration) =>
      Function(self.lower_function_declaration(declaration))
    Let(declaration) => Let(self.lower_let_declaration(declaration))
  }
}

///|
fn AnfLowerer::lower_function_declaration(
  self : AnfLowerer,
  declaration : @checked.CheckedFunctionDeclaration,
) -> AnfFunctionDeclaration {
  {
    symbol: declaration.symbol,
    name: declaration.name,
    type_parameters: declaration.type_parameters,
    parameters: declaration.parameters,
    return_type: declaration.return_type,
    body: self.lower_expr(declaration.body),
    type_: declaration.type_,
    loc: declaration.loc,
  }
}

///|
fn AnfLowerer::lower_let_declaration(
  self : AnfLowerer,
  declaration : @checked.CheckedLetDeclaration,
) -> AnfLetDeclaration {
  {
    symbol: declaration.symbol,
    name: declaration.name,
    value: self.lower_expr(declaration.initializer),
    type_: declaration.type_,
    loc: declaration.loc,
  }
}

///|
fn AnfLowerer::lower_expr(
  self : AnfLowerer,
  expression : @checked.CheckedExpr,
) -> AnfExpr {
  self.lower_to_atom(expression, fn(atom) {
    Atom(atom~, type_=atom.type_(), loc=atom.loc())
  })
}

///|
fn AnfLowerer::lower_to_atom(
  self : AnfLowerer,
  expression : @checked.CheckedExpr,
  continuation : (AnfAtom) -> AnfExpr,
) -> AnfExpr {
  match expression {
    Literal(literal~, type_~, loc~) =>
      continuation(Literal(literal~, type_~, loc~))
    Value(name~, symbol~, type_~, loc~) =>
      continuation(Value(name~, symbol~, type_~, loc~))
    UnsafeBuiltin(name~, type_~, loc~) =>
      continuation(UnsafeBuiltin(name~, type_~, loc~))
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      body~,
      type_~,
      loc~
    ) =>
      continuation(
        self.lower_function_atom(
          type_parameters, parameters, return_type, body, type_, loc,
        ),
      )
    TypeApplication(callee~, arguments~, type_~, loc~) =>
      self.lower_to_atom(callee, fn(callee) {
        self.bind_temp(
          TypeApplication(callee~, arguments~, type_~, loc~),
          type_,
          loc,
          continuation,
        )
      })
    Block(items~, result~, loc~, ..) =>
      self.lower_items(
        items,
        0,
        fn() { self.lower_to_atom(result, continuation) },
        loc,
      )
    If(condition~, then_branch~, else_branch~, loc~, ..) =>
      self.lower_to_atom(condition, fn(condition) {
        let then_branch = self.lower_to_atom(then_branch, continuation)
        let else_branch = self.lower_to_atom(else_branch, continuation)
        If(
          condition~,
          then_branch~,
          else_branch~,
          type_=then_branch.type_(),
          loc~,
        )
      })
    Match(scrutinee~, arms~, loc~, ..) =>
      self.lower_to_atom(scrutinee, fn(scrutinee) {
        let arms = arms.map(fn(arm) {
          {
            pattern: arm.pattern,
            body: self.lower_to_atom(arm.body, continuation),
            loc: arm.loc,
          }
        })
        let type_ = if arms.is_empty() {
          @types.Type::Error
        } else {
          arms[0].body.type_()
        }
        Match(scrutinee~, arms~, type_~, loc~)
      })
    Call(callee~, arguments~, type_~, loc~) =>
      self.lower_to_atom(callee, fn(callee) {
        self.lower_exprs_to_atoms(arguments, 0, [], fn(arguments) {
          self.bind_temp(
            Call(callee~, arguments~, type_~, loc~),
            type_,
            loc,
            continuation,
          )
        })
      })
    OperationCall(operation~, arguments~, type_~, loc~, ..) =>
      self.lower_exprs_to_atoms(arguments, 0, [], fn(arguments) {
        self.bind_temp(
          OperationCall(operation~, arguments~, type_~, loc~),
          type_,
          loc,
          continuation,
        )
      })
    Handler(..) => abort("Lane handler lowering to ANF is not implemented yet")
    Field(base~, field~, name~, type_~, loc~, ..) =>
      self.lower_to_atom(base, fn(base) {
        self.bind_temp(
          Field(base~, field~, name~, type_~, loc~),
          type_,
          loc,
          continuation,
        )
      })
    StructLiteral(
      symbol~,
      type_arguments~,
      type_witnesses~,
      fields~,
      type_~,
      loc~
    ) =>
      self.lower_struct_fields(fields, 0, [], fn(fields) {
        self.bind_temp(
          Struct(
            symbol~,
            type_arguments~,
            type_witnesses~,
            fields~,
            type_~,
            loc~,
          ),
          type_,
          loc,
          continuation,
        )
      })
    Variant(symbol~, type_arguments~, arguments~, type_~, loc~) =>
      self.lower_exprs_to_atoms(arguments, 0, [], fn(arguments) {
        self.bind_temp(
          Variant(symbol~, type_arguments~, arguments~, type_~, loc~),
          type_,
          loc,
          continuation,
        )
      })
  }
}

///|
fn AnfLowerer::lower_function_atom(
  self : AnfLowerer,
  type_parameters : Array[@types.TypeParameter],
  parameters : Array[@checked.CheckedValueParameter],
  return_type : @types.Type,
  body : @checked.CheckedExpr,
  type_ : @types.Type,
  loc : SourceSpan,
) -> AnfAtom {
  let effect = match type_ {
    Function(_, _, effect) => effect
    Forall(_, Function(_, _, effect)) => effect
    _ => Empty
  }
  let function_type = @types.Type::Function(
    parameters.map(fn(parameter) { parameter.type_ }),
    return_type,
    effect,
  )
  let function = AnfAtom::Function(
    parameters~,
    body=self.lower_expr(body),
    type_=function_type,
    loc~,
  )
  if type_parameters.is_empty() {
    function
  } else {
    TypeLambda(type_parameters~, body=function, type_~, loc~)
  }
}

///|
fn AnfLowerer::bind_temp(
  self : AnfLowerer,
  rhs : AnfRhs,
  type_ : @types.Type,
  loc : SourceSpan,
  continuation : (AnfAtom) -> AnfExpr,
) -> AnfExpr {
  let temp = self.fresh_temp()
  let atom = AnfAtom::Temp(temp~, type_~, loc~)
  let body = continuation(atom)
  Let(binding=Temp(temp~, rhs~, type_~, loc~), body~, type_=body.type_(), loc~)
}

///|
fn AnfLowerer::lower_items(
  self : AnfLowerer,
  items : Array[@checked.CheckedLocalItem],
  index : Int,
  continuation : () -> AnfExpr,
  loc : SourceSpan,
) -> AnfExpr {
  if index >= items.length() {
    continuation()
  } else {
    match items[index] {
      Let(declaration) =>
        self.lower_to_atom(declaration.initializer, fn(initializer) {
          let body = self.lower_items(items, index + 1, continuation, loc)
          Let(
            binding=Value(
              symbol=declaration.symbol,
              name=declaration.name,
              rhs=Atom(initializer),
              type_=declaration.type_,
              loc=declaration.loc,
            ),
            body~,
            type_=body.type_(),
            loc~,
          )
        })
      PatternLet(declaration) =>
        self.lower_to_atom(declaration.initializer, fn(initializer) {
          let body = self.lower_items(items, index + 1, continuation, loc)
          Let(
            binding=Pattern(
              pattern=declaration.pattern,
              initializer~,
              loc=declaration.loc,
            ),
            body~,
            type_=body.type_(),
            loc~,
          )
        })
      Function(declaration) => {
        let atom = self.lower_function_atom(
          declaration.type_parameters,
          declaration.parameters,
          declaration.return_type,
          declaration.body,
          declaration.type_,
          declaration.loc,
        )
        let body = self.lower_items(items, index + 1, continuation, loc)
        Let(
          binding=Value(
            symbol=declaration.symbol,
            name=Some(declaration.name),
            rhs=Atom(atom),
            type_=declaration.type_,
            loc=declaration.loc,
          ),
          body~,
          type_=body.type_(),
          loc~,
        )
      }
    }
  }
}

///|
fn AnfLowerer::lower_exprs_to_atoms(
  self : AnfLowerer,
  expressions : Array[@checked.CheckedExpr],
  index : Int,
  atoms : Array[AnfAtom],
  continuation : (Array[AnfAtom]) -> AnfExpr,
) -> AnfExpr {
  if index >= expressions.length() {
    continuation(atoms)
  } else {
    self.lower_to_atom(expressions[index], fn(atom) {
      let next_atoms = atoms.copy()
      next_atoms.push(atom)
      self.lower_exprs_to_atoms(
        expressions,
        index + 1,
        next_atoms,
        continuation,
      )
    })
  }
}

///|
fn AnfLowerer::lower_struct_fields(
  self : AnfLowerer,
  fields : Array[@checked.CheckedStructLiteralField],
  index : Int,
  lowered : Array[AnfStructField],
  continuation : (Array[AnfStructField]) -> AnfExpr,
) -> AnfExpr {
  if index >= fields.length() {
    continuation(lowered)
  } else {
    let field = fields[index]
    self.lower_to_atom(field.value, fn(value) {
      let next = lowered.copy()
      next.push({
        symbol: field.symbol,
        name: field.name,
        value,
        loc: field.loc,
      })
      self.lower_struct_fields(fields, index + 1, next, continuation)
    })
  }
}
