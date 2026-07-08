# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

- Use MoonBit bitstring patterns for bytes parsing throughout the repository.
  When parsing binary data, model the input as a `BytesView` and write small
  pattern-matching parser steps for fixed layouts, tags, and byte-string
  prefixes. Follow the style in
  `modules/lanec/compile/artifact_binary.mbt`, for example matching artifact
  headers with patterns such as
  `[.. b"LANEART\x00", u8be(version), u8be(kind), i32le(payload_length), .. body]`.
  Do not hand-roll byte-by-byte parsing for new binary formats unless a
  pattern-based parser would make the code less clear or would lose necessary
  diagnostics.

- Treat repeated file name prefixes as a package-boundary smell. When a
  directory grows many files like `artifact_binary_*.mbt` or
  `module_compile_*.mbt`, consider whether those files are really an independent
  package. Before moving them, check dependency direction first: the new package
  should own a coherent API and must not create a cycle with the parent package.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. For snapshot tests that record
  structured debugging output, derive `Debug` and use `debug_inspect`, rather
  than deriving `Show` for debugging. For solid, well-defined results (e.g.
  scientific computations), prefer assertion tests. You can use
  `moon coverage analyze > uncovered.log` to see which parts of your code are
  not covered by tests. Prefer `assert_false(condition)` over
  `assert_true(!condition)` for negative boolean assertions.

- For structured outputs, prefer inspecting the whole value when it implements
  `Debug` or can be rendered readably as a string. Do not assert structured
  output by searching rendered strings, such as
  `inspect(response.contains("\"status\":0"), content="true")`, and avoid
  splitting a readable result into many narrow field assertions such as
  asserting an array length and then each element shape. Use `inspect`,
  `debug_inspect`, or `json_inspect` on the complete value whenever the whole
  output is small enough to review.

- Prefer `if value is Pattern(binding)` for one-branch pattern checks whose
  fallback is `()`. For example, write
  `if diagnostic.source_id is Some(source_id) { ... }` instead of a `match`
  with `Some(...) => ...` and `None => ()`.
