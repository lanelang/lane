///|
struct DiagnosticArchitectureReport {
  forbidden_markers : Array[String]
  missing_owner_files : Array[String]
  missing_owner_entries : Array[String]
} derive(Debug, Eq)

///|
test "diagnostic ownership stays phase-local" {
  let diagnostic_source = read_compile_source("compile.mbt")
  let report : DiagnosticArchitectureReport = {
    forbidden_markers: forbidden_diagnostic_markers(diagnostic_source),
    missing_owner_files: missing_diagnostic_owner_files(),
    missing_owner_entries: missing_diagnostic_owner_entries(),
  }
  debug_inspect(
    report,
    content=(
      #|{
      #|  forbidden_markers: [],
      #|  missing_owner_files: [],
      #|  missing_owner_entries: [],
      #|}
    ),
  )
}

///|
fn forbidden_diagnostic_markers(source : String) -> Array[String] {
  let markers = [
    "CompileErrorKind", "TypeMismatch(", "EffectMismatch(", "GenericArgumentInferenceFailed(",
    "NonExhaustiveMatch(", "UnresolvedValue(", "DuplicateTopLevelValue(", "UnexpectedToken(",
  ]
  markers.filter(fn(marker) { source.contains(marker) })
}

///|
fn missing_diagnostic_owner_files() -> Array[String] {
  [
    "../module/compile/compile_boundary_diagnostic.mbt", "../module/compile/artifact_diagnostic.mbt",
    "../module/compile/link_diagnostic.mbt", "../parser/diagnostic.mbt", "../resolve/diagnostic.mbt",
    "../typecheck/diagnostic.mbt",
  ].filter(fn(path) { !compile_source_exists(path) })
}

///|
fn missing_diagnostic_owner_entries() -> Array[String] {
  let entries : Array[(String, String)] = [
    (
      "../module/compile/compile_boundary_diagnostic.mbt", "compile_boundary_diagnostic(",
    ),
    ("../module/compile/artifact_diagnostic.mbt", "artifact_diagnostic("),
    ("../module/compile/link_diagnostic.mbt", "link_diagnostic("),
    ("../parser/diagnostic.mbt", "impl @compiler_diag.ToCompilerDiagnostic"),
    ("../resolve/diagnostic.mbt", "impl @compiler_diag.ToCompilerDiagnostic"),
    ("../typecheck/diagnostic.mbt", "impl @compiler_diag.ToCompilerDiagnostic"),
  ]
  entries
  .filter(fn(entry) {
    let (path, marker) = entry
    !read_compile_source(path).contains(marker)
  })
  .map(fn(entry) {
    let (path, marker) = entry
    "\{path}: \{marker}"
  })
}

///|
fn read_compile_source(path : String) -> String {
  for candidate in compile_source_candidates(path) {
    if @fs.path_exists(candidate) {
      return @fs.read_file_to_string(candidate, encoding="utf8") catch {
        _ => abort("failed to read \{candidate}")
      }
    }
  }
  abort("compile source file not found: \{path}")
}

///|
fn compile_source_exists(path : String) -> Bool {
  compile_source_candidates(path).any(fn(candidate) {
    @fs.path_exists(candidate)
  })
}

///|
fn compile_source_candidates(path : String) -> Array[String] {
  let module_path = if path.has_prefix("../") {
    "modules/lanec/\{path[3:]}"
  } else {
    "modules/lanec/compile/\{path}"
  }
  let candidates = [path, module_path]
  for root in project_root_candidates() {
    candidates.push(join_path(root, module_path))
  }
  candidates
}

///|
fn project_root_candidates() -> Array[String] {
  let candidates = ["."]
  if @env.current_dir() is Some(current_dir) {
    let mut path = current_dir
    for _ in 0..<12 {
      candidates.push(path)
      match parent_path(path) {
        Some(parent) => path = parent
        None => return candidates
      }
    }
  }
  candidates
}

///|
fn parent_path(path : String) -> String? {
  for index = path.length() - 1; index >= 0; index = index - 1 {
    if path[index] == '/' {
      if index == 0 {
        return Some("/")
      }
      return Some(path[:index].to_owned())
    }
  } nobreak {
    None
  }
}

///|
fn join_path(root : String, path : String) -> String {
  if root == "." {
    path
  } else if root == "/" {
    "/\{path}"
  } else {
    "\{root}/\{path}"
  }
}
