///|
pub fn VM::new(
  inst? : Inst = Return,
  env? : Environment = Environment::base(),
) -> VM {
  { //
    acc: Value::default(),
    next: inst,
    env,
    rib: [],
    stack: None,
  }
}

///|
fn VM::save_frame(vm : VM, ret : Inst) -> Frame {
  { ret, env: vm.env, rib: vm.rib, stack: vm.stack }
}

///|
fn VM::load_frame(vm : VM, frame : Frame) -> Unit {
  vm.next = frame.ret
  vm.env = frame.env
  vm.rib = frame.rib
  vm.stack = frame.stack
}

///|
pub fn VM::run_one_step(vm : VM) -> Unit raise SchemeException {
  match vm.next {
    // Const
    Const(v, next) => {
      vm.acc = v
      vm.next = next
    }
    // Env
    Refer(name, next) => {
      vm.acc = vm.env.lookup(name)
      vm.next = next
    }
    Set(name, next) => {
      vm.env.set_var(name, vm.acc)
      vm.acc = Value::default()
      vm.next = next
    }
    Define(name, next) => {
      vm.env.define_var(name, vm.acc)
      vm.acc = Value::default()
      vm.next = next
    }
    // Control
    Branch(nt, nf) =>
      vm.next = match vm.acc {
        False => nf
        _ => nt
      }
    Return =>
      match vm.stack {
        None => () // Halt
        Some(saved_frame) => vm.load_frame(saved_frame)
      }
    Close(parm_names, body, name, next) => {
      vm.acc = Closure({ env: vm.env, parm_names, body, name })
      vm.next = next
    }
    // Apply
    Save(next, ret) => {
      vm.stack = Some(vm.save_frame(ret))
      vm.next = next
    }
    Args(args_length, next) => {
      vm.rib = FixedArray::make(args_length, Value::default())
      vm.next = next
    }
    Push(i, next) => {
      vm.rib[i] = vm.acc
      vm.next = next
    }
    Apply => vm.apply()
  }
}

///|
fn VM::apply(vm : VM) -> Unit raise SchemeException {
  match vm.acc {
    Closure(clo) => {
      guard vm.rib.length() == clo.parm_names.length() else {
        raise ArgumentCount
      }
      vm.env = clo.env.extend(clo.parm_names, vm.rib, clo)
      vm.next = clo.body
    }
    Primitive(p) =>
      match p {
        Normal(body, ..) => {
          vm.acc = body(vm.rib)
          vm.next = Return
        }
        CallCC => {
          guard vm.rib is [f] else { raise ArgumentCount }
          vm.acc = f
          vm.rib[0] = Continuation(vm.stack)
          vm.apply()
        }
        Apply => {
          guard vm.rib is [f, v] else { raise ArgumentCount }
          guard v.list_tail_and_length() is (Nil, length) else {
            raise TypeError(1)
          }
          vm.acc = f
          vm.rib = v.unsafe_to_fixedarray(length)
          vm.apply()
        }
      }
    Continuation(stack) => {
      guard vm.rib is [v] else { raise ArgumentCount }
      vm.acc = v
      vm.stack = stack
      vm.next = Return
    }
    _ => raise CallNonProcedure
  }
}

///|
pub fn VM::run_to_halt(vm : VM) -> Unit raise SchemeException {
  for {
    match (vm.next, vm.stack) {
      (Return, None) => break
      _ => vm.run_one_step()
    }
  }
}
