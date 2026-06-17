///|
pub async fn read_protocol_message(input : &@io.Reader) -> @jsonrpc.Message? {
  let length = read_content_length(input)
  guard length is Some(length) else { return None }
  let body = @utf8.decode(input.read_exactly(length))
  let json = @json.parse(body)
  let message : @jsonrpc.Message = @json.from_json(json)
  Some(message)
}

///|
async fn read_content_length(input : &@io.Reader) -> Int? {
  let mut content_length = None
  while input.read_until("\n") is Some(line) {
    let line = line.trim().to_owned()
    if line == "" {
      return content_length
    }
    if header_name(line).to_lower() == "content-length" {
      content_length = parse_content_length(line)
    }
  }
  None
}

///|
fn header_name(line : String) -> String {
  match line.find(":") {
    Some(index) => line.unsafe_substring(start=0, end=index)
    None => ""
  }
}

///|
fn parse_content_length(line : String) -> Int? {
  guard line.find(":") is Some(index) else { return None }
  let value = line
    .unsafe_substring(start=index + 1, end=line.length())
    .trim()
    .to_owned()
  Some(@string.parse_int(value, base=10)) catch {
    _ => None
  }
}

///|
pub async fn write_protocol_message(
  output : &@io.Writer,
  message : @jsonrpc.Message,
) -> Unit {
  let body = message.to_json().stringify()
  output.write("Content-Length: \{@utf8.encode(body).length()}\r\n\r\n")
  output.write(body)
}
