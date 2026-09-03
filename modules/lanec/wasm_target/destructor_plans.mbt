///|
priv enum WasmDestructorAction {
  ReleaseReference(offset~ : Int)
  ReleaseCallable(offset~ : Int)
  ReleaseErased(value_offset~ : Int, witness_offset~ : Int)
} derive(Eq)

///|
priv struct WasmDestructorPlan {
  actions : Array[WasmDestructorAction]
} derive(Eq)

///|
priv struct WasmDestructorCatalog {
  plans : Array[WasmDestructorPlan]
  shape_roles : Array[WasmHelperFunctionRole]
}

///|
fn object_destructor_plan(shape : @physical.ObjectShape) -> WasmDestructorPlan {
  let layout = object_shape_layout(shape)
  let (witness_base, schemas) = match shape {
    Data(data) => (layout.witness_base, data.members)
    Environment(environment) => (layout.witness_base, environment.members)
  }
  let actions : Array[WasmDestructorAction] = []
  for index, schema in schemas {
    let offset = layout.member_offsets[index]
    match schema.cleanup {
      Trivial => ()
      OwnedRef => actions.push(ReleaseReference(offset~))
      OwnedCallable => actions.push(ReleaseCallable(offset~))
      OwnedErased =>
        actions.push(
          ReleaseErased(
            value_offset=offset,
            witness_offset=witness_base + schema.witness_ordinal.unwrap() * 4,
          ),
        )
    }
  }
  { actions, }
}

///|
fn plan_wasm_destructors(
  image : @physical.PhysicalProgram,
) -> WasmDestructorCatalog {
  let plans : Array[WasmDestructorPlan] = []
  let shape_roles : Array[WasmHelperFunctionRole] = []
  for shape in image.object_shapes {
    let plan = object_destructor_plan(shape)
    if plan.actions.is_empty() {
      shape_roles.push(DestroyNoop)
      continue
    }
    let mut plan_index = -1
    for index, existing in plans {
      if existing == plan {
        plan_index = index
        break
      }
    }
    if plan_index < 0 {
      plan_index = plans.length()
      plans.push(plan)
    }
    shape_roles.push(DestroyPlan(plan=plan_index))
  }
  { plans, shape_roles, }
}

///|
fn WasmDestructorCatalog::shape_role(
  self : WasmDestructorCatalog,
  shape : Int,
) -> WasmHelperFunctionRole {
  self.shape_roles[shape]
}

///|
fn WasmDestructorCatalog::plan(
  self : WasmDestructorCatalog,
  plan : Int,
) -> WasmDestructorPlan {
  self.plans[plan]
}
