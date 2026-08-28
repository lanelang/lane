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
  let lowered = @anf.lower_cps_core_to_runtime_anf({
    program: program.certify().unwrap(),
    retained_values: [outer],
    function_origins: @function_origin.FunctionOriginCatalog::uniform(
      program,
      SourceWritten,
    ),
  }).unwrap()
  debug_inspect(
    lowered.terms(),
    content=(
      #|<ArrayView:
      #|  [
      #|    LetRec(
      #|      [
      #|        {
      #|          id: { index: 0 },
      #|          rhs: Function(
      #|            {
      #|              id: { value: 0 },
      #|              source: Some({ index: 0 }),
      #|              origin: SourceWritten,
      #|              parameters: [],
      #|              result_type: Scalar(I64),
      #|              body: Let(
      #|                Value(
      #|                  id={ index: 1 },
      #|                  rhs=Atom(
      #|                    JoinPoint(
      #|                      {
      #|                        id: { value: 1 },
      #|                        source: Some({ index: 1 }),
      #|                        origin: SourceWritten,
      #|                        parameters: [],
      #|                        result_type: Scalar(I64),
      #|                        body: Atom(Literal(I64(42))),
      #|                      },
      #|                    ),
      #|                  ),
      #|                ),
      #|                Let(
      #|                  Temp(
      #|                    temp={ index: 0 },
      #|                    type_=Scalar(I64),
      #|                    rhs=Call(callee=Ref({ index: 1 }), arguments=[]),
      #|                  ),
      #|                  Atom(Temp({ index: 0 })),
      #|                ),
      #|              ),
      #|            },
      #|          ),
      #|        },
      #|      ],
      #|    ),
      #|  ]>
    ),
  )
}
