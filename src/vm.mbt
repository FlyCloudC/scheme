///|
pub fn VM::new(
  inst~ : Inst = Return,
  env~ : Environment = Environment::base(),
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
fn Frame::save(vm : VM, ret : Inst) -> Frame {
  { ret, env: vm.env, rib: vm.rib, stack: vm.stack }
}

///|
fn load_frame(self : VM, frame : Frame) -> Unit {
  self.next = frame.ret
  self.env = frame.env
  self.rib = frame.rib
  self.stack = frame.stack
}

///|
pub fn run_one_step(self : VM) -> Unit raise SchemeException {
  match self.next {
    // Const
    Const(v, next) => {
      self.acc = v
      self.next = next
    }
    // Env
    Refer(name, next) => {
      self.acc = self.env.lookup(name)
      self.next = next
    }
    Set(name, next) => {
      self.env.set_var(name, self.acc)
      self.acc = Value::default()
      self.next = next
    }
    Define(name, next) => {
      self.env.define_var(name, self.acc)
      self.acc = Value::default()
      self.next = next
    }
    // Control
    Branch(nt, nf) =>
      self.next = match self.acc {
        False => nf
        _ => nt
      }
    Return =>
      match self.stack {
        None => () // Halt
        Some(saved_frame) => self.load_frame(saved_frame)
      }
    Close(parm_names, body, name, next) => {
      self.acc = Closure({ env: self.env, parm_names, body, name })
      self.next = next
    }
    // Apply
    Save(next, ret) => {
      self.stack = Some(Frame::save(self, ret))
      self.next = next
    }
    Args(args_length, next) => {
      self.rib = FixedArray::make(args_length, Value::default())
      self.next = next
    }
    Push(i, next) => {
      self.rib[i] = self.acc
      self.next = next
    }
    Apply => self.apply()
  }
}

///|
fn apply(self : VM) -> Unit raise SchemeException {
  match self.acc {
    Closure(clo) => {
      guard self.rib.length() == clo.parm_names.length() else {
        raise ArgumentCount
      }
      self.env = clo.env.extend(clo.parm_names, self.rib, clo)
      self.next = clo.body
    }
    Primitive(p) =>
      match p {
        Normal(body, ..) => {
          self.acc = body(self.rib)
          self.next = Return
        }
        CallCC => {
          guard self.rib is [f] else { raise ArgumentCount }
          self.acc = f
          self.rib[0] = Continuation(self.stack)
          self.apply()
        }
        Apply => {
          guard self.rib is [f, v] else { raise ArgumentCount }
          guard v.list_tail_and_length() is (Nil, length) else {
            raise TypeError(1)
          }
          self.acc = f
          self.rib = v.unsafe_to_fixedarray(length)
          self.apply()
        }
      }
    Continuation(stack) => {
      guard self.rib is [v] else { raise ArgumentCount }
      self.acc = v
      self.stack = stack
      self.next = Return
    }
    _ => raise CallNonProcedure
  }
}

///|
pub fn run_to_halt(self : VM) -> Unit raise SchemeException {
  for {
    match (self.next, self.stack) {
      (Return, None) => break
      _ => self.run_one_step()
    }
  }
}
