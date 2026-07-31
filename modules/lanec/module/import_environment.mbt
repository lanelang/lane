///|
/// The interface environments one **Module** compiles against.
///
/// `direct` holds the interfaces the module imports by name. Only those
/// interfaces contribute importable declarations, unqualified names, module
/// bindings, and **Visible Offers**.
///
/// `available` additionally holds every interface transitively reachable
/// through public interface references. Semantic lookup needs those interfaces
/// because fields, type members, variants, and effect operations are
/// **Owner-Visible Members**: their visibility follows the exported type, not
/// the importing module. A module that receives a value of an imported type
/// may therefore project its fields without importing the module that declares
/// the type.
///
/// `available` keeps interface values intact. Buslane lowering collects type
/// dependencies from imported value signatures, so hiding them here would lose
/// nominal dependencies. Value *visibility* is a separate rule applied by
/// `typecheck_environment`.
pub(all) struct ModuleImportEnvironments {
  direct : ImportedEnvironment
  available : ImportedEnvironment
} derive(Debug, Eq)

///|
/// Builds both environments for one module from the module paths it imports by
/// name and the pool of interfaces a driver can supply.
///
/// `direct` follows `direct_module_paths` and silently skips paths the pool
/// does not provide; callers that must diagnose missing imports compare the
/// resulting length against the requested path count.
///
/// `available` is the transitive closure over interface type and effect
/// references, in depth-first discovery order from the direct imports. That
/// ordering depends only on the module and the interfaces it reaches, so it
/// does not vary with the order a driver happens to hold its pool in. Closing
/// over interface references rather than over a source-level import graph keeps
/// the rule usable by source-set compilation, separate compilation from
/// interface artifacts, and the semantic workspace alike.
pub fn ModuleImportEnvironments::from_pool(
  direct_module_paths : Array[String],
  pool : ImportedEnvironment,
) -> ModuleImportEnvironments {
  let direct = []
  for module_path in direct_module_paths {
    if pool.find(module_path) is Some(interface) {
      direct.push(interface)
    }
  }
  let available = []
  for interface in direct {
    collect_reachable_interfaces(interface.module_path, pool, available)
  }
  { direct: { modules: direct }, available: { modules: available } }
}

///|
/// Appends the interface named by `module_path` and everything it reaches.
///
/// `type_references` and `effect_references` already accumulate transitively
/// while an interface is built, but recursing keeps the closure correct for
/// interfaces produced by an older or partial pipeline.
fn collect_reachable_interfaces(
  module_path : String,
  pool : ImportedEnvironment,
  collected : Array[ModuleInterface],
) -> Unit {
  if collected.any(interface => interface.module_path == module_path) {
    return
  }
  guard pool.find(module_path) is Some(interface) else { return }
  collected.push(interface)
  for reference in interface.type_references {
    collect_reachable_interfaces(reference.module_path, pool, collected)
  }
  for reference in interface.effect_references {
    collect_reachable_interfaces(reference.module_path, pool, collected)
  }
}

///|
/// The environment type checking resolves declarations against.
///
/// Non-direct interfaces keep their nominal shapes, effects, and type aliases
/// so that **Owner-Visible Members** stay reachable, but lose values and
/// optimization hints: a module must not name a value it did not import.
pub fn ModuleImportEnvironments::typecheck_environment(
  self : ModuleImportEnvironments,
) -> ImportedEnvironment {
  {
    modules: self.available.modules.map(interface => {
      if self.direct.find(interface.module_path) is Some(_) {
        interface
      } else {
        { ..interface, values: [], optimization_hints: [] }
      }
    }),
  }
}
