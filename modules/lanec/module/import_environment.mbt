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
  direct : ModuleInterfaceCatalog
  available : ModuleInterfaceCatalog
} derive(Debug, Eq)

///|
/// Builds both environments for one module from the module paths it imports by
/// name and the pool of interfaces a driver can supply.
///
/// `direct` follows `direct_module_paths` and silently skips paths the pool
/// does not provide; callers that must diagnose missing imports compare the
/// resulting length against the requested path count.
///
/// `available` is the **Reachable Interface Closure**: the transitive closure
/// over what each interface's content references, in depth-first discovery
/// order from the direct imports. A module reached only through another
/// module's implementation, and never named in its public surface, does not
/// appear. That ordering depends only on the module and the interfaces it
/// reaches, so it does not vary with the order a driver happens to hold its
/// pool in. Closing over interface content rather than over a source-level
/// import graph keeps the rule usable by source-set compilation, separate
/// compilation from interface artifacts, and the semantic workspace alike.
pub fn ModuleImportEnvironments::from_pool(
  direct_module_paths : Array[String],
  pool : ModuleInterfaceCatalog,
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
fn collect_reachable_interfaces(
  module_path : String,
  pool : ModuleInterfaceCatalog,
  collected : Array[ModuleInterface],
) -> Unit {
  if collected.any(interface => interface.module_path == module_path) {
    return
  }
  guard pool.find(module_path) is Some(interface) else { return }
  collected.push(interface)
  for dependency in interface.dependency_module_paths() {
    collect_reachable_interfaces(dependency, pool, collected)
  }
}

///|
/// The environment type checking resolves declarations against.
///
/// Name visibility is already fixed by the resolver's import symbols. Keeping
/// the complete catalog here lets later semantic phases follow declaration
/// owners without reconstructing a second, filtered interface model.
pub fn ModuleImportEnvironments::typecheck_environment(
  self : ModuleImportEnvironments,
) -> ModuleInterfaceCatalog {
  self.available
}
