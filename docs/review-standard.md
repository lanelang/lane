# Lane Review Standard

The Lane language is designed to be elegant; the compiler must be its equal.
Tests provide evidence for correctness, but no test suite proves it. This review
asks whether the evidence supports the behavior claims and whether the design is
a work of art: nothing missing, nothing extra, nothing accidental.

## The aesthetic, concretely
- No special cases. A rule holds uniformly or the rule is wrong; a branch added for one caller means the seam is misplaced — move the seam, never add the case.
- Uniformity has no exemptions: generated code, %-binders, and dead metadata obey the same laws as user code. "Unused" never excuses "illegal".
- Meaning lives in structure, never in spelling: no decision may hinge on the text of a name; ids and shapes carry the semantics.
- One owner per fact: every derived fact has exactly one producer. A second site computing the same thing is tomorrow's divergence, hence today's defect.
- Duality is honored: dual concepts (define/lookup, lower/verify, parameter/result) get dual shapes and dual names; every asymmetry needs a written reason.
- Code reads as inevitable, not clever: if believing it correct requires the commit message, it fails.

## The architecture
- The pipeline is a chain of verified representations: every IR stage boundary passes the verifier owned by that IR layer, and every Buslane boundary passes the Buslane verifier; no stage trusts its input or silently repairs it.
- A persistent or exchangeable IR is a first-class interchange language: it has a stable printer, parser or decoder, codec for each persisted form, verifier, and round-trip tests across every supported representation.
- A transient compiler-internal IR has a stable human-readable printer, a verifier at its stage boundaries, and structured debug output where diagnosis needs it. It needs no parser or codec without a real persistence, interchange, or tooling consumer; adding one speculatively is itself extra code.
- Problems are fixed where they are created, never masked downstream — dead-code elimination is not a fix, and phase order follows meaning, not convenience.
- One responsibility per independently meaningful module or package boundary, stated in the nearest owning CONTEXT.md in one paragraph that matches the code. A leaf package with no independent responsibility may inherit its parent's context instead of duplicating it.
- The glossary is law: every concept has exactly one name, defined in CONTEXT.md and used verbatim in code, tests, and issues; synonym drift is a finding.
- Invariants are enforced by construction or checked by a verifier; a comment is not an enforcement mechanism.
- Tests pin contracts, not implementation accidents: a test that a legal refactor breaks is itself a finding.

## The method
- Root causes only: a workaround, patch, or compatibility shim is a top-severity finding. When the architecture is the bug, the finding must say so.
- Interface compatibility is never a reason to preserve a wrong design; rewrite the callers.
- Claims are measured, not argued: a root cause counts as established only with instrumentation or a minimal reproduction behind it.
- Findings are filed as issues/ISS-###.md with evidence; nothing is fixed silently mid-review.
- Mechanical gates (formatting, warnings, full test suite, examples corpus) are assumed prerequisites, not review content.

Severity: broken invariant → P0–P1; violated aesthetic → P1–P2; vocabulary drift → P2–P3.
