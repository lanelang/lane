///|
test "ANF assigns stable identities and preserves binding provenance" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let outer = metadata.define_value(
    "outer",
    Function,
    Function([], Primitive(I64), Empty),
  )
  let inner = metadata.define_value(
    "inner",
    Local,
    Function([], Primitive(I64), Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: outer,
          rhs: Function({
            parameters: [],
            result_type: Primitive(I64),
            body: Let(
              inner,
              Function({
                parameters: [],
                result_type: Primitive(I64),
                body: Literal(I64(42L)),
              }),
              Call(Ref(inner), []),
            ),
          }),
        },
      ]),
    ],
  }
  let lowered = @anf.lower_buslane_program_to_anf(program)
  debug_inspect(
    lowered.terms,
    content=(
      #|[
      #|  LetRec(
      #|    [
      #|      {
      #|        id: { index: 0 },
      #|        rhs: Function(
      #|          {
      #|            id: { value: 0 },
      #|            source: Some({ index: 0 }),
      #|            parameters: [],
      #|            result_type: Primitive(I64),
      #|            body: Let(
      #|              Value(
      #|                id={ index: 1 },
      #|                rhs=Atom(
      #|                  Function(
      #|                    {
      #|                      id: { value: 1 },
      #|                      source: Some({ index: 1 }),
      #|                      parameters: [],
      #|                      result_type: Primitive(I64),
      #|                      body: Atom(Literal(I64(42))),
      #|                    },
      #|                  ),
      #|                ),
      #|              ),
      #|              Let(
      #|                Temp(
      #|                  temp={ index: 0 },
      #|                  rhs=Call(callee=Ref({ index: 1 }), arguments=[]),
      #|                ),
      #|                Atom(Temp({ index: 0 })),
      #|              ),
      #|            ),
      #|          },
      #|        ),
      #|      },
      #|    ],
      #|  ),
      #|]
    ),
  )
}
