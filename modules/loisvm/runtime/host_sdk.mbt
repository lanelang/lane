///|
struct HostParameter[T] {
  kind : RuntimeValueKind
  decode : (HostValue) -> T
}

///|
pub fn HostParameter::unit() -> HostParameter[Unit] {
  {
    kind: Unit,
    decode: value => {
      match value {
        Unit => ()
        _ => abort("typed host binding received a non-Unit value")
      }
    },
  }
}

///|
pub fn HostParameter::bool() -> HostParameter[Bool] {
  {
    kind: Bool,
    decode: value => {
      match value {
        Bool(value) => value
        _ => abort("typed host binding received a non-Bool value")
      }
    },
  }
}

///|
pub fn HostParameter::i64() -> HostParameter[Int64] {
  {
    kind: I64,
    decode: value => {
      match value {
        I64(value) => value
        _ => abort("typed host binding received a non-I64 value")
      }
    },
  }
}

///|
pub fn HostParameter::f64() -> HostParameter[Double] {
  {
    kind: F64,
    decode: value => {
      match value {
        F64(value) => value
        _ => abort("typed host binding received a non-F64 value")
      }
    },
  }
}

///|
pub fn HostParameter::f32() -> HostParameter[Float] {
  {
    kind: F32,
    decode: value => {
      match value {
        F32(value) => value
        _ => abort("typed host binding received a non-F32 value")
      }
    },
  }
}

///|
pub fn HostParameter::string() -> HostParameter[HostStringView] {
  {
    kind: String,
    decode: value => {
      match value {
        BorrowedString(value) => value
        _ => abort("typed host binding received a non-String value")
      }
    },
  }
}

///|
pub fn[T] HostParameter::host_object(
  store : HostObjectStore[T],
) -> HostParameter[T] {
  {
    kind: Opaque,
    decode: value => {
      match value {
        BorrowedOpaque(value) => store.project(value)
        _ => abort("typed host binding received a non-Opaque value")
      }
    },
  }
}

///|
struct HostParameters[T] {
  kinds : Array[RuntimeValueKind]
  decode : (ArrayView[HostValue]) -> T
}

///|
pub fn HostParameters::none() -> HostParameters[Unit] {
  {
    kinds: [],
    decode: values => {
      if !values.is_empty() {
        abort("typed host binding received unexpected arguments")
      }
      ()
    },
  }
}

///|
pub fn[T] HostParameters::one(
  parameter : HostParameter[T],
) -> HostParameters[T] {
  {
    kinds: [parameter.kind],
    decode: values => {
      if values.length() != 1 {
        abort("typed host binding received the wrong argument count")
      }
      (parameter.decode)(values[0])
    },
  }
}

///|
pub fn[A, B] HostParameters::pair(
  left : HostParameters[A],
  right : HostParameters[B],
) -> HostParameters[(A, B)] {
  let left_length = left.kinds.length()
  let right_length = right.kinds.length()
  {
    kinds: left.kinds + right.kinds,
    decode: values => {
      if values.length() != left_length + right_length {
        abort("typed host binding received the wrong argument count")
      }
      (
        (left.decode)(values[:left_length]),
        (right.decode)(values[left_length:]),
      )
    },
  }
}

///|
struct HostResult[T] {
  kind : RuntimeValueKind
  encode : (T) -> HostValue
}

///|
pub fn HostResult::unit() -> HostResult[Unit] {
  { kind: Unit, encode: _ => Unit, }
}

///|
pub fn HostResult::bool() -> HostResult[Bool] {
  { kind: Bool, encode: value => Bool(value), }
}

///|
pub fn HostResult::i64() -> HostResult[Int64] {
  { kind: I64, encode: value => I64(value), }
}

///|
pub fn HostResult::f64() -> HostResult[Double] {
  { kind: F64, encode: value => F64(value), }
}

///|
pub fn HostResult::f32() -> HostResult[Float] {
  { kind: F32, encode: value => F32(value), }
}

///|
pub fn HostResult::string() -> HostResult[String] {
  { kind: String, encode: value => String(@utf8.encode(value)), }
}

///|
pub fn[T] HostResult::host_object(
  store : HostObjectStore[T],
  finalizer~ : (T) -> Unit,
) -> HostResult[T] {
  {
    kind: Opaque,
    encode: value => OwnedOpaque(OwnedHostObject::new(store, value, finalizer~)),
  }
}

///|
pub fn[Arguments, Result] RuntimeBinding::typed(
  symbol~ : String,
  abi_major~ : Int,
  parameters~ : HostParameters[Arguments],
  result~ : HostResult[Result],
  invoke~ : (RuntimeContext, Arguments) -> Result raise RuntimeImportFailure,
) -> RuntimeBinding {
  RuntimeBinding::new(
    symbol~,
    abi_major~,
    parameters=parameters.kinds,
    result=result.kind,
    invoke=(context, values) => {
      let arguments = (parameters.decode)(values)
      (result.encode)(invoke(context, arguments))
    },
  )
}
