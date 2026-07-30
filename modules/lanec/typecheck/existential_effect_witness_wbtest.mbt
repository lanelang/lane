///|
test "struct existential witnesses accept effect arguments" {
  let result = expect_typecheck_result(
    (
      #|effect Log {
      #|  write() -> Unit
      #|}
      #|struct Task {
      #|  type E : Effect
      #|  action : () -> Unit ! E
      #|}
      #|fn[E : Effect] pack(action : () -> Unit ! E) -> Task {
      #|  Task::{ E = E, action }
      #|}
      #|fn pure() -> Task {
      #|  Task::{ E = {}, action: fn() { () } }
      #|}
      #|fn logged() -> Task {
      #|  Task::{
      #|    E = { Log },
      #|    action: fn() {
      #|      Log::write!()
      #|    },
      #|  }
      #|}
    ),
  )
  assert_eq(result.diagnostics, [])
}

///|
test "struct existential witnesses enforce member kinds" {
  let result = expect_typecheck_result(
    (
      #|struct EffectBox {
      #|  type E : Effect
      #|}
      #|struct TypeBox {
      #|  type T : Type
      #|}
      #|fn invalid_effect() -> EffectBox {
      #|  EffectBox::{ E = Int }
      #|}
      #|fn invalid_type() -> TypeBox {
      #|  TypeBox::{ T = {} }
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: KindMismatch(expected=Effect, actual=Type),
      #|    loc: {
      #|      start_offset: 140,
      #|      end_offset: 143,
      #|      start_line: 9,
      #|      start_column: 20,
      #|      end_line: 9,
      #|      end_column: 23,
      #|    },
      #|  },
      #|  {
      #|    kind: KindMismatch(expected=Type, actual=Effect),
      #|    loc: {
      #|      start_offset: 196,
      #|      end_offset: 198,
      #|      start_line: 12,
      #|      start_column: 18,
      #|      end_line: 12,
      #|      end_column: 20,
      #|    },
      #|  },
      #|]
    ),
  )
}
