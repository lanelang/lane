///|
pub struct Member {
  priv name : String
  priv value : Json?
}

///|
pub fn required(name : String, value : Json) -> Member {
  { name, value: Some(value), }
}

///|
pub fn optional(name : String, value : Json?) -> Member {
  { name, value, }
}

///|
/// Constructs a JSON object in member order. An optional `None` member is
/// absent; `Some(Json::null())` keeps an explicit JSON null member.
pub fn object(fields : Array[Member]) -> Json {
  let members : Map[String, Json] = Map([])
  for field in fields {
    if field.value is Some(value) {
      members[field.name] = value
    }
  }
  Json::object(members)
}
