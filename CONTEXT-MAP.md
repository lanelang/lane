# Context Map

This repository has multiple glossary contexts. Use this map to choose the
right `CONTEXT.md` before adding or changing domain terms.

## Contexts

**Lane Workspace**: [CONTEXT.md](CONTEXT.md)
Repository-wide language and workflow terms shared by compiler, core language,
and tools.

**Lane Compiler**: [modules/lanec/CONTEXT.md](modules/lanec/CONTEXT.md)
Compiler front-end, source elaboration, semantic lowering, and compiler
analysis API terms.

**Buslane**: [modules/buslane/CONTEXT.md](modules/buslane/CONTEXT.md)
Typed semantic core language, verifier, interpreter, and Buslane program terms.

**Lane Command**: [modules/lane/CONTEXT.md](modules/lane/CONTEXT.md)
Native command-line tool and language-server command terms.

**Lane Wasm**: [modules/lane_wasm/CONTEXT.md](modules/lane_wasm/CONTEXT.md)
Browser-facing Lane tool terms for wasm-hosted IR exploration.

## Routing Notes

- Use **Module** for the Lane source-language namespace defined in the root
  glossary.
- Use **MoonBit module** or **MoonBit package** when discussing MoonBit
  packaging boundaries.
- Use **Lane Wasm** for the browser-facing wasm tool surface, and use
  `Milky2018/lane_wasm` only for the MoonBit packaging identity.
- Put terms that apply across compiler, core language, and tools in the root
  context.
- Put tool-specific terms in the closest tool context instead of the root
  context.
- Use **Pre-Buslane Contract** for the checked-source to Buslane boundary; the
  detailed contract lives in `modules/lanec/docs/pre-buslane-contract.md`.
