///|
pub(all) enum ArtifactValue {
  Atom(String)
  Text(String)
} derive(Debug, Eq)

///|
pub(all) enum ArtifactEntry {
  Tag(String)
  Value(String, ArtifactValue)
  Block(String, String)
} derive(Debug, Eq)

///|
pub(all) struct ArtifactDocument {
  version : String
  kind : String
  entries : Array[ArtifactEntry]
} derive(Debug, Eq)

///|
pub fn parse_text(text : String) -> Result[ArtifactDocument, String] {
  let tokens = tokens_from_string(text) catch {
    ArtifactLexerError(message) => return Err(message)
  }
  let yacc_tokens = tokens.map(fn(item) {
    let (token, loc) = item
    (token, loc, loc)
  })
  let document = artifact_document(yacc_tokens) catch {
    UnexpectedEndOfInput(_, _) => return Err("unexpected end of artifact")
    UnexpectedToken(_, _, _) => return Err("unexpected artifact token")
  }
  if document.version != "lane-artifact-text-v1" {
    Err("unsupported artifact text version " + document.version)
  } else if document.kind != "interface" &&
    document.kind != "object" &&
    document.kind != "program" {
    Err("unknown artifact kind " + document.kind)
  } else {
    Ok(document)
  }
}
