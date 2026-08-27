name = "Milky2018/lane_runtime"

version = "0.1.0"

readme = "README.mbt.md"

repository = ""

license = "MIT"

keywords = [ "language", "runtime", "wasm" ]

description = "The Lane host ABI and WebAssembly execution runtime."

preferred_target = "native"

import {
  "Milky2018/milkir@0.6.3",
  "Milky2018/wasm_core@0.5.3",
  "Milky2018/wasmoon@0.12.4",
  "Milky2018/wasmoon_jit@0.7.3",
  "moonbit-community/prettyprinter@0.4.10",
}
