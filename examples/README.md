# Lane Examples

These files are executable conformance fixtures for the parser, resolver, type
checker, elaborator, Buslane checker, command line tool, and reference
interpreter.

- `valid/*.lane` should parse and type check.
- `invalid/*.lane` should be rejected for the reason stated in the leading
  comment.

The examples follow the language specification rather than the current
implementation. Rejecting a `valid` example or accepting an `invalid` example
is an implementation discrepancy unless the specification changes.

Examples that use standard operations import the relevant standard-library
modules explicitly. `lane run` fixtures pass those modules with `--lib-dir`.
