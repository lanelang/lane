///|
test "simplify ANF atom aliases without reordering calls" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let function = metadata.define_value(
    "function",
    External,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let first = metadata.define_value("first", Local, Primitive(Int))
  let second = metadata.define_value("second", Local, Primitive(Int))
  let result = metadata.define_value("result", Local, Primitive(Int))
  let first_temp = AnfTempId::{ index: 0 }
  let alias_temp = AnfTempId::{ index: 1 }
  let call_temp = AnfTempId::{ index: 2 }
  let program = AnfProgram::{
    metadata,
    terms: [
      External(function),
      Let(
        result,
        Let(
          Value(id=first, rhs=Atom(Literal(Int(42L)))),
          Let(
            Temp(temp=first_temp, rhs=Atom(Ref(first))),
            Let(
              Value(id=second, rhs=Atom(Temp(first_temp))),
              Let(
                Temp(temp=alias_temp, rhs=Atom(Ref(second))),
                Let(
                  Temp(
                    temp=call_temp,
                    rhs=Call(callee=Ref(function), arguments=[Temp(alias_temp)]),
                  ),
                  Atom(Temp(call_temp)),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  }
  debug_inspect(
    simplify_anf_program(program).terms,
    content=(
      #|[
      #|  External({ index: 0 }),
      #|  Let(
      #|    { index: 3 },
      #|    Let(
      #|      Temp(
      #|        temp={ index: 2 },
      #|        rhs=Call(callee=Ref({ index: 0 }), arguments=[Literal(Int(42))]),
      #|      ),
      #|      Atom(Temp({ index: 2 })),
      #|    ),
      #|  ),
      #|]
    ),
  )
}

///|
test "simplify ANF aliases inside function and match scopes" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_value("parameter", Parameter, Primitive(Int))
  let local_alias = metadata.define_value("alias", Local, Primitive(Int))
  let binder = metadata.define_value("binder", Local, Primitive(Int))
  let result = metadata.define_value(
    "result",
    Value,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let function = Function({
    parameters: [parameter],
    result_type: Primitive(Int),
    body: Let(
      Value(id=local_alias, rhs=Atom(Ref(parameter))),
      Match({
        scrutinee: Ref(local_alias),
        binder,
        result_type: Primitive(Int),
        alternatives: [
          {
            alt_constructor: Default,
            type_binders: [],
            value_binders: [],
            body: Atom(Ref(local_alias)),
          },
        ],
      }),
    ),
  })
  let program = AnfProgram::{ metadata, terms: [Let(result, Atom(function))] }
  debug_inspect(
    simplify_anf_program(program).terms,
    content=(
      #|[
      #|  Let(
      #|    { index: 3 },
      #|    Atom(
      #|      Function(
      #|        {
      #|          parameters: [{ index: 0 }],
      #|          result_type: Primitive(Int),
      #|          body: Match(
      #|            {
      #|              scrutinee: Ref({ index: 0 }),
      #|              binder: { index: 2 },
      #|              result_type: Primitive(Int),
      #|              alternatives: [
      #|                {
      #|                  alt_constructor: Default,
      #|                  type_binders: [],
      #|                  value_binders: [],
      #|                  body: Atom(Ref({ index: 0 })),
      #|                },
      #|              ],
      #|            },
      #|          ),
      #|        },
      #|      ),
      #|    ),
      #|  ),
      #|]
    ),
  )
}
