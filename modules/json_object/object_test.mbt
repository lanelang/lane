///|
test "optional JSON fields distinguish absence from null" {
  json_inspect(
    @json_object.object([
      @json_object.required("required", "value".to_json()),
      @json_object.optional("omitted", None),
      @json_object.optional("nullable", Some(Json::null())),
    ]),
    content={ "required": "value", "nullable": null },
  )
}
