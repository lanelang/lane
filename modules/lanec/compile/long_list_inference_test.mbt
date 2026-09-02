///|
fn list_provider_source() -> @module_frontend.SourceInput {
  {
    source_id: "list-provider",
    text: (
      #|module Basic.Data.List
      #|pub enum List[T] {
      #|  empty()
      #|  cons(T, List[T])
      #|}
    ),
  }
}

///|
test "generic inference checks a long list literal in linear source work" {
  let items = Array::makei(128, index => index.to_string()).join(", ")
  let outcome = check({
    root: {
      source_id: "main",
      text: (
        #|module Main
        #|import Basic.Data.List.*
        #|
        #|fn[T] identity(value : T) -> T { value }
        #|
        #|pub let values : List[I64] = identity([
        #|  
      ) +
      items +
      "\n])",
    },
    libraries: [list_provider_source()],
  })
  guard outcome is Succeeded(_, warnings) else {
    fail("expected the long list literal to typecheck")
  }
  assert_eq(warnings.diagnostics(), [])
}

///|
test "generic inference still checks list elements after fixing the owner type" {
  let outcome = check({
    root: {
      source_id: "main",
      text: (
        #|module Main
        #|import Basic.Data.List.*
        #|
        #|fn[T] identity(value : T) -> T { value }
        #|
        #|pub let values : List[I64] = identity([1, true])
      ),
    },
    libraries: [list_provider_source()],
  })
  guard outcome is Failed(failure) else {
    fail("expected the heterogeneous list literal to be rejected")
  }
  debug_inspect(
    failure.diagnostics(),
    content=(
      #|[
      #|  {
      #|    source_id: Some("main"),
      #|    message: "type mismatch",
      #|    span: Some(
      #|      Source(
      #|        source_id="main",
      #|        span={
      #|          start_offset: 122,
      #|          end_offset: 126,
      #|          start_line: 6,
      #|          start_column: 43,
      #|          end_line: 6,
      #|          end_column: 47,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E3006"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="main",
      #|          span={
      #|            start_offset: 122,
      #|            end_offset: 126,
      #|            start_line: 6,
      #|            start_column: 43,
      #|            end_line: 6,
      #|            end_column: 47,
      #|          },
      #|        ),
      #|        message: "expected `I64`, found `Bool`",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["Lane does not insert implicit conversions between different types"],
      #|    helps: ["change the expression type or adjust the annotation/expected type"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}
