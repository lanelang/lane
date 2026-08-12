# Lane Examples

These files are conformance fixtures for the parser, resolver, type checker, elaborator, Buslane checker, command line tool, and reference interpreter.

- `valid/*.lane` should parse and type check.
- `invalid/*.lane` should be rejected for the reason stated in the leading comment.
- `warnings/*.lane` should type check but produce the documented warning under warning-deny fixture runs.

The examples follow the language specification rather than the current implementation. Rejecting a `valid` example or accepting an `invalid` example is an implementation discrepancy unless the specification changes.

Initialize the pinned Basic fixture, build one release executable, and pass it
to the examples checker:

```sh
git submodule update --init --checkout basic
moon build --target native --release modules/lane
tools/check-lane-run-examples.sh \
  "$PWD/_build/native/release/build/Milky2018/lane/lane.exe"
```

The examples checker uses the clean, pinned `basic` submodule as `LANE_HOME`
and rejects a missing, dirty, or revision-mismatched fixture. Only entries with
executable `() -> Unit` shapes are exercised through `lane run`.
