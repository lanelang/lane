# Source Prettyprinter

This internal package derives from the document core of
`moonbit-community/prettyprinter` 0.4.10. Lane owns this smaller layout module
so source line comments can be represented as layout primitives rather than
ordinary text.

`line_comment` appends a line comment to the current line and guarantees that
the next text document starts on a new line at its own nesting indentation.
The package intentionally exposes only the document operations used by Lane's
source syntax formatter.
