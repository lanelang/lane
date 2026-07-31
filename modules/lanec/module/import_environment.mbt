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
/// references, ordered by discovery: direct imports in import order, then
/// references in the order the interfaces declare them. That ordering depends
/// only on the module and the interfaces it reaches, so it does not vary with
/// the order a driver happens to hold its pool in. Closing over interface
/// references rather than over a source-level import graph keeps the rule
/// usable by source-set compilation, separate compilation from interface
/// artifacts, and the semantic workspace alike.
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
  let reachable : Array[String] = []
  for interface in direct {
    push_unique_module_path(reachable, interface.module_path)
  }
  // `type_references` and `effect_references` already accumulate transitively
  // during interface construction, but a worklist keeps the rule correct even
  // for interfaces produced by an older or partial pipeline.
  for index = 0; index < reachable.length(); index = index + 1 {
    guard pool.find(reachable[index]) is Some(interface) else { continue }
    for reference in interface.type_references {
      push_unique_module_path(reachable, reference.module_path)
    }
    for reference in interface.effect_references {
      push_unique_module_path(reachable, reference.module_path)
    }
  }
  let available = []
  for module_path in reachable {
    if pool.find(module_path) is Some(interface) {
      available.push(interface)
    }
  }
  { direct: { modules: direct }, available: { modules: available } }
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

///|
fn push_unique_module_path(paths : Array[String], module_path : String) -> Unit {
  if !paths.contains(module_path) {
    paths.push(module_path)
  }
}
