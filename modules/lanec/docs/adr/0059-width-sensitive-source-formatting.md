# Width-Sensitive Source Formatting

Lane source formatting is width-sensitive but uses a soft line-width contract: syntax-owned breakpoints should prefer the configured width, while indivisible atoms such as identifiers, module paths, comments, and string literals may exceed it. The formatter should implement this in `lanec` syntax pretty-printing with shared formatting primitives for list-like delimiters, signatures, assignments, operator chains, and access chains, not by post-processing rendered text in command-line tools.

The default formatting width is fixed at 100 for user-facing tools; smaller widths are only an internal test/API input. Broken comma lists use one item per line, two-space indentation, an independent closing delimiter line, and no trailing comma. Expression continuations put binary, pipeline, and field-access operators at the start of continuation lines. Comment attachment and string/comment reflow are out of scope for this formatter contract.
