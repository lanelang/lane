# Lane Examples

These files are conformance fixtures for the parser, resolver, type checker,
elaborator, Buslane checker, command line tool, and reference interpreter.

- `valid/*.lane` should parse and type check.
- `invalid/*.lane` should be rejected for the reason stated in the leading
  comment.
- `warnings/*.lane` should type check but produce the documented warning under
  warning-deny fixture runs.

The examples follow the language specification rather than the current
implementation. Rejecting a `valid` example or accepting an `invalid` example
is an implementation discrepancy unless the specification changes.

Examples that use Basic operations import the relevant Basic library
modules explicitly. Smoke fixtures pass those modules with `--lib-dir`, and
only entries with executable `() -> Unit` shapes are exercised through
`lane run`.
