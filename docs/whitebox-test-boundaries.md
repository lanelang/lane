# White-box test boundaries

Lane tests public behavior through black-box packages or the built executable by
default. A white-box suite is retained only when it must construct, observe, or
fault-inject package-private state. The table below is an exact allowlist;
`tools/check-whitebox-test-boundaries.sh` rejects an undocumented or stale
entry.

Shared setup files are listed because `_wbtest.mbt` grants private package
access even when the file itself declares no test. A reason describes the
private invariant, not merely the subsystem being tested.

| Suite | Private invariant |
| --- | --- |
| `modules/buslane/buslane_wbtest.mbt` | Constructs impossible metadata registry identities to verify internal identity diagnostics. |
| `modules/buslane/interpreter/interpreter_wbtest.mbt` | Installs private host-effect handlers and observes interpreter-only dispatch precedence and registration validation. |
| `modules/buslane/text/float_text_wbtest.mbt` | Observes the canonical text renderer's exact private IEEE-bit spelling before public parsing. |
| `modules/lane/command_wbtest.mbt` | Inspects the private argparse-to-`LaneCommand` value mapping after executable behavior is covered externally. |
| `modules/lane/compile_support_wbtest.mbt` | Supplies package-private compilation fixtures used by Lane orchestration tests. |
| `modules/lane/explore_wbtest.mbt` | Inspects the private HTML stage renderer and escaping boundary without writing a report file. |
| `modules/lane/lane_wbtest.mbt` | Fault-injects private command outcomes, filesystem seams, source-closure selection, and execution orchestration. |
| `modules/lane/lsp/lsp_wbtest.mbt` | Drives private handler transitions and workspace snapshots to isolate protocol conversion and cache invariants. |
| `modules/lane/lsp/workspace_analysis_wbtest.mbt` | Injects private workspace scanner failures that cannot be produced portably through `run_server`. |
| `modules/lane/terminal/terminal_wbtest.mbt` | Supplies private TTY and environment probes to verify terminal color policy deterministically. |
| `modules/lane_wasm/core_wbtest.mbt` | Inspects private Explore Protocol request decoding and stage-state construction before Wasm export serialization. |
| `modules/lanec/abi/intrinsic_wbtest.mbt` | Reads the compiler-private intrinsic registry to pin exact names and ABI signatures. |
| `modules/lanec/analysis/byte_bytes_wbtest.mbt` | Inspects raw semantic index entries and primitive identities before public workspace projection. |
| `modules/lanec/analysis/completion_source_wbtest.mbt` | Observes the private token/line index used to classify completion cursor positions. |
| `modules/lanec/analysis/enrich_checked_wbtest.mbt` | Constructs malformed checked metadata and inspects generated-local provenance filtering. |
| `modules/lanec/analysis/f32_wbtest.mbt` | Pins the raw semantic hover type identity produced by checked-expression enrichment. |
| `modules/lanec/analysis/import_alias_wbtest.mbt` | Inspects alias binding identities and reference entries inside the semantic index. |
| `modules/lanec/analysis/lint_parity_wbtest.mbt` | Compares the private analysis diagnostic collection with compiler-owned lint facts. |
| `modules/lanec/analysis/semantic_workspace_wbtest.mbt` | Observes revision caches, semantic fingerprints, dependency invalidation, and index reuse. |
| `modules/lanec/anf/anf_wbtest.mbt` | Snapshots the package-private ANF representation produced from Buslane terms. |
| `modules/lanec/anf/simplify_wbtest.mbt` | Inspects ANF alias elimination and sequencing before the next lowering boundary. |
| `modules/lanec/artifact/module_reference_wbtest.mbt` | Constructs and decodes private module-reference tags independently of complete artifacts. |
| `modules/lanec/checked/checked_wbtest.mbt` | Inspects checked IR printing, value-use groups, and authored/synthetic argument provenance. |
| `modules/lanec/checked/derive_wbtest.mbt` | Observes private derive recipes and their traversal substitutions. |
| `modules/lanec/checked/function_effect_widen_wbtest.mbt` | Inspects the checked expression node that records function-effect widening. |
| `modules/lanec/compile/analysis_wbtest.mbt` | Observes complete compiler analysis entries and checked-source spans before public query filtering. |
| `modules/lanec/compile/artifact_link_validation_wbtest.mbt` | Mutates artifact side tables and identities into states unavailable through public source compilation. |
| `modules/lanec/compile/artifact_roundtrip_wbtest.mbt` | Inspects intermediate interface, object, linked Buslane, and bytecode representations in one package-local pipeline. |
| `modules/lanec/compile/byte_bytes_wbtest.mbt` | Inspects lowered Byte/Bytes layouts, callable ABIs, cleanup, and bytecode shapes. |
| `modules/lanec/compile/derive_wbtest.mbt` | Inspects canonical derive interfaces, generated checked declarations, and malformed provider metadata. |
| `modules/lanec/compile/diagnostic_support_wbtest.mbt` | Provides private diagnostic request fixtures for compile-package white-box suites. |
| `modules/lanec/compile/effect_specialization_example37_wbtest.mbt` | Captures and verifies the private monadic-lift stage for real regression fixtures. |
| `modules/lanec/compile/existential_effect_witness_wbtest.mbt` | Inspects compiled existential witness metadata before executable erasure. |
| `modules/lanec/compile/f32_wbtest.mbt` | Observes F32 lowering, layouts, artifacts, and bytecode rather than only source acceptance. |
| `modules/lanec/compile/fatal_control_wbtest.mbt` | Inspects the private finalized bytecode image to prove direct, indirect, and adapter calls share the `Never` ABI without a Runtime Import. |
| `modules/lanec/compile/i32_wbtest.mbt` | Observes I32 representation and arithmetic after executable lowering. |
| `modules/lanec/compile/import_alias_wbtest.mbt` | Inspects canonical identities retained in interface/object artifacts after alias resolution. |
| `modules/lanec/compile/legacy_support_wbtest.mbt` | Provides private legacy fixture adapters used only by compile-package white-box regressions. |
| `modules/lanec/compile/model_wbtest.mbt` | Mutates nested diagnostic arrays to verify private facade construction performs deep isolation. |
| `modules/lanec/compile/numeric_intrinsic_artifact_wbtest.mbt` | Inspects numeric intrinsic identities inside module object metadata. |
| `modules/lanec/compile/pipeline_wbtest.mbt` | Observes compiler stage provenance and post-lowering handler structure. |
| `modules/lanec/compile/source_graph_wbtest.mbt` | Inspects root/library module graph selection, retained declarations, and internal compiled-program shape. |
| `modules/lanec/compile/sugar_provider_wbtest.mbt` | Inspects canonical provider resolution and checked inference under desugared tuple/list forms. |
| `modules/lanec/compile/utf8_intrinsics_wbtest.mbt` | Inspects UTF-8 intrinsic artifact tags, representation erasure, and rejected legacy schemas. |
| `modules/lanec/core_opt/metadata_allocation_wbtest.mbt` | Injects an exhausted private registry and proves optimization returns no partial program. |
| `modules/lanec/desugar/desugar_wbtest.mbt` | Snapshots resolved-to-desugared IR shapes and authored/synthetic argument provenance. |
| `modules/lanec/effect_lowering/core/handler_elaboration_wbtest.mbt` | Inspects private Invoke/Install handler IR before monadic transformation. |
| `modules/lanec/effect_lowering/core/metadata_allocation_wbtest.mbt` | Injects allocator exhaustion at the private monadic-transform boundary. |
| `modules/lanec/effect_lowering/core/mon_trans_validate_wbtest.mbt` | Constructs forbidden private monadic-transform forms and checks stage diagnostics. |
| `modules/lanec/effect_lowering/core/mon_trans_wbtest.mbt` | Inspects effect classification and selective bind insertion in private core IR. |
| `modules/lanec/effect_lowering/core/monadic_lift_wbtest.mbt` | Constructs unresolved private context markers rejected by monadic lift. |
| `modules/lanec/effect_lowering/core/open_resolve_wbtest.mbt` | Inspects resolution of private open-context plans and missing-context failures. |
| `modules/lanec/effect_lowering/core/residual_effect_erasure_wbtest.mbt` | Observes private residual-effect rows and extern structure at the erasure boundary. |
| `modules/lanec/effect_lowering/core/synthesis_wbtest.mbt` | Inspects synthesized effects on private Invoke, Install, and open-effect nodes. |
| `modules/lanec/effect_lowering/core/verify_wbtest.mbt` | Constructs malformed extended effect IR and checks verifier provenance. |
| `modules/lanec/effect_lowering/cps/abi_wbtest.mbt` | Inspects CPS callable shapes, metadata ownership, continuations, and consumability direction. |
| `modules/lanec/effect_lowering/cps/context_schema_wbtest.mbt` | Observes dictionary schemas and higher-kinded companion/residual projections. |
| `modules/lanec/effect_lowering/cps/install_semantics_wbtest.mbt` | Inspects outer/inner dictionary selection and generic handler clause materialization. |
| `modules/lanec/effect_lowering/cps/install_wbtest.mbt` | Observes private CPS installation and relay structure across multi-shot resumptions. |
| `modules/lanec/effect_lowering/cps/metadata_allocation_wbtest.mbt` | Injects allocator exhaustion and proves CPS emits no partial rewrite. |
| `modules/lanec/effect_lowering/cps/monadic_lift_integration_wbtest.mbt` | Captures private monadic-lift output to inspect continuation captures and erased binders. |
| `modules/lanec/effect_lowering/cps/output_wbtest.mbt` | Provides private CPS output observers shared by stage-specific white-box suites. |
| `modules/lanec/effect_lowering/cps/pipeline_integration_wbtest.mbt` | Inspects ordered open-context arguments between private CPS pipeline stages. |
| `modules/lanec/effect_lowering/cps/test_imports_wbtest.mbt` | Re-exports private CPS test fixtures within the white-box compilation mode. |
| `modules/lanec/effect_specialization/allocation_wbtest.mbt` | Mutates post-plan metadata to prove allocation consumes the immutable constructor plan. |
| `modules/lanec/effect_specialization/error_wbtest.mbt` | Constructs planner/allocator/rewriter invariant failures and inspects typed phase context. |
| `modules/lanec/effect_specialization/planner_wbtest.mbt` | Inspects private demands, retention order, substituted use classification, and fixed-point planning. |
| `modules/lanec/effect_specialization/rewrite_wbtest.mbt` | Inspects private specialization clones, lexical scopes, substitutions, and forwarding rewrites. |
| `modules/lanec/elaborate/buslane_lowering/buslane_lowering_wbtest.mbt` | Snapshots private pre-Buslane forms, witness materialization, and exact lowered Buslane structure. |
| `modules/lanec/elaborate/buslane_lowering/char_wbtest.mbt` | Inspects Char literal/pattern representation in lowered Buslane. |
| `modules/lanec/elaborate/buslane_lowering/metadata_allocation_wbtest.mbt` | Injects exhausted metadata and proves lowering exposes no partial externals. |
| `modules/lanec/elaborate/buslane_lowering/uninhabited_match_wbtest.mbt` | Inspects the empty-alternative Buslane form and its type-error distinction. |
| `modules/lanec/executable/effect_specialization_integration_wbtest.mbt` | Captures private specialization and lift stages plus internal error adaptation. |
| `modules/lanec/executable/extended_verification_wbtest.mbt` | Inspects producer-stage provenance retained by the private extended verifier. |
| `modules/lanec/format/format_internals_wbtest.mbt` | Observes trivia ownership, delimiter indexes, and unconsumed-comment detection. |
| `modules/lanec/loisvm_lowering/f32_wbtest.mbt` | Inspects explicit runtime representation bridges for erased generic F32 calls. |
| `modules/lanec/loisvm_lowering/lower_wbtest.mbt` | Snapshots private ANF/VM CFG, slot layout, adapter plans, and emitted bytecode. |
| `modules/lanec/loisvm_lowering/special_constants_wbtest.mbt` | Reads compiler-generated IEEE bit patterns before runtime execution. |
| `modules/lanec/loisvm_lowering/uninhabited_match_wbtest.mbt` | Inspects unreachable bytecode emitted for an empty data match. |
| `modules/lanec/module/compile/interface_freshen_wbtest.mbt` | Constructs unmapped binders and inspects private interface identity freshening. |
| `modules/lanec/module/compile/phase_wbtest.mbt` | Observes checked-to-compiled phase products and absence of partial output on failure. |
| `modules/lanec/module/frontend/input_wbtest.mbt` | Inspects lexical fallback headers and canonical dependency extraction before parsing. |
| `modules/lanec/module/link/identity_wbtest.mbt` | Exercises private namespace identity maps and first-binding collision policy. |
| `modules/lanec/module/link/metadata_allocation_wbtest.mbt` | Injects linker allocator exhaustion and verifies no partial linked program. |
| `modules/lanec/module/semantic_fingerprint_wbtest.mbt` | Observes private semantic/presentation fingerprints and exact invalidation inputs. |
| `modules/lanec/occurrence/occurrence_wbtest.mbt` | Inspects private call, escape, effect, and reachability summaries. |
| `modules/lanec/parser/layout_internals_wbtest.mbt` | Observes inserted layout tokens and delimiter-continuation bookkeeping. |
| `modules/lanec/resolve/import_alias_wbtest.mbt` | Inspects private module bindings, authored-use marks, and canonical alias identities. |
| `modules/lanec/resolve/resolve_wbtest.mbt` | Snapshots resolved symbols, lexical scopes, and generated binding identities. |
| `modules/lanec/symbol/symbol_wbtest.mbt` | Observes private registry namespaces, generated provenance, and measurement identities. |
| `modules/lanec/syntax/pretty_wbtest.mbt` | Constructs syntax AST values directly to pin precedence and canonical rendering. |
| `modules/lanec/typecheck/byte_bytes_wbtest.mbt` | Inspects checked builtin signatures and internal mismatch diagnostics for Byte/Bytes. |
| `modules/lanec/typecheck/char_wbtest.mbt` | Observes checked Char patterns and primitive identity in type mismatch facts. |
| `modules/lanec/typecheck/declarations_wbtest.mbt` | Inspects declaration environments, existential metadata, kinds, and checked public surfaces. |
| `modules/lanec/typecheck/effects_wbtest.mbt` | Inspects effect constraints, widening nodes, residual rows, and solver diagnostics. |
| `modules/lanec/typecheck/existential_effect_witness_wbtest.mbt` | Observes checked existential effect witnesses and member-kind enforcement. |
| `modules/lanec/typecheck/expressions_wbtest.mbt` | Snapshots checked expression nodes, inferred types/effects, and introduction/elimination decisions. |
| `modules/lanec/typecheck/f32_wbtest.mbt` | Inspects exact F32 literal rounding and checked builtin signature validation. |
| `modules/lanec/typecheck/generics_wbtest.mbt` | Observes local inference constraints, instantiations, binders, and higher-kinded applications. |
| `modules/lanec/typecheck/i32_wbtest.mbt` | Inspects checked I32 literal range diagnostics and builtin contracts. |
| `modules/lanec/typecheck/i64_wbtest.mbt` | Inspects sign-folded I64 literal bounds at the checked-expression boundary. |
| `modules/lanec/typecheck/nominal_wbtest.mbt` | Observes nominal substitutions, field/variant metadata, coverage, and contextual inference. |
| `modules/lanec/typecheck/patterns_wbtest.mbt` | Snapshots checked pattern binders, coverage facts, and existential openings. |
| `modules/lanec/typecheck/typecheck_support_wbtest.mbt` | Supplies private checker construction and checked-IR assertion helpers. |
| `modules/lanec/typecheck/utf8_intrinsics_wbtest.mbt` | Inspects exact checked Char/UTF-8 intrinsic contracts and removed intrinsic rejection. |
| `modules/lanec/types/types_wbtest.mbt` | Drives private normalization budgets and checked failure propagation at exact boundaries. |
| `modules/lanec/vmcfg/consume_projections_wbtest.mbt` | Inspects consuming projection selection and block-local borrow grouping. |
| `modules/lanec/vmcfg/devirtualize_wbtest.mbt` | Observes callable escape analysis and direct-call/environment rewrites. |
| `modules/lanec/vmcfg/finalize_wbtest.mbt` | Inspects ownership promotion, physical slots, callable ABI IDs, and finalized bodies. |
| `modules/lanec/vmcfg/flow_analysis_wbtest.mbt` | Observes private dominator and value-flow fixed points over synthetic CFGs. |
| `modules/lanec/vmcfg/simplify_wbtest.mbt` | Snapshots private CFG threading, parameter removal, constant reuse, and layout liveness. |
| `modules/loisvm/bytecode/instruction_codec_wbtest.mbt` | Enumerates private instruction constructors to prove codec symmetry exhaustively. |
| `modules/loisvm/bytecode/malformed_codec_wbtest.mbt` | Constructs malformed binary tables and framing states unavailable through the public verified encoder. |
| `modules/loisvm/interp/execute_wbtest.mbt` | Observes interpreter frame, singleton, ARC, trap, and host-value internals. |
| `modules/loisvm/interp/globals_wbtest.mbt` | Inspects private global ownership cleanup after initializer and entry failures. |
| `modules/loisvm/interp/heap_wbtest.mbt` | Injects impossible capacities into private heap allocation arithmetic. |
| `modules/loisvm/interp/host_objects_wbtest.mbt` | Constructs stale private host-object handles inside an interpreter instance. |
| `modules/loisvm/runtime/host_objects_wbtest.mbt` | Constructs out-of-range host-object slot handles before public runtime dispatch. |
| `modules/loisvm/wasm/compiler/callable_table_wbtest.mbt` | Inspects private address-taken callable tables and frame-liveness locals. |
