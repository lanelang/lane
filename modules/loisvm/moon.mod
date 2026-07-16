name = "Milky2018/loisvm"

version = "0.1.0"

readme = "README.mbt.md"

repository = ""

license = "MIT"

keywords = [ "language", "virtual-machine", "bytecode", "wasm" ]

description = "A language-independent bytecode and execution runtime for MoonBit hosts."

preferred_target = "native"

import {
  "Milky2018/bytecodec@0.1.0",
  "Milky2018/machv_emit@0.2.2",
  "Milky2018/wasm_core@0.1.2",
  "Milky2018/wasmoon@0.7.0",
  "Milky2018/wasmoon_jit@0.2.0",
}
