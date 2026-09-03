# JSON Object Context

## JSON Object

A JSON Object is constructed from an ordered sequence of required and optional
members. An optional `None` member is absent; `Some(Json::null())` is present
with the JSON null value. This package owns that distinction and stable member
ordering for hand-written JSON encoders in the workspace.
