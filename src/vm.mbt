///|
pub fn VM::new(
  inst~ : Inst = Return,
  env~ : Environment = Environment::base()
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
pub fn run_one_step(self : VM) -> Unit!SchemeException {
  match self.next {
    Const(v, next) => {
      self.acc = v
      self.next = next
    }
    Refer(name, next) => {
      self.acc = self.env.lookup!(name)
      self.next = next
    }
    Return =>
      match self.stack {
        None => () // Halt
        Some(saved_frame) => {
          self.next = saved_frame.ret
          self.env = saved_frame.env
          self.rib = saved_frame.rib
          self.stack = saved_frame.stack
        }
      }
    Close(parm_names, body, name, next) => {
      self.acc = Closure({ env: self.env, parm_names, body, name })
      self.next = next
    }
    Branch(nt, nf) =>
      self.next = match self.acc {
        False => nf
        _ => nt
      }
    Save(next, ret) => {
      self.stack = Some({ ret, env: self.env, rib: self.rib, stack: self.stack })
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
    Apply => self.apply!()
    Set(name, next) => {
      self.env.set_var!(name, self.acc)
      self.acc = Value::default()
      self.next = next
    }
    Define(name, next) => {
      self.env.define_var(name, self.acc)
      self.acc = Value::default()
      self.next = next
    }
  }
}

///|
fn apply(self : VM) -> Unit!SchemeException {
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
          self.acc = body!(self.rib)
          self.next = Return
        }
        CallCC => {
          guard let [f] = self.rib else { _ => raise ArgumentCount }
          self.acc = f
          self.rib[0] = Continuation(self.stack)
          self.apply!()
        }
      }
    Continuation(stack) => {
      guard let [v] = self.rib else { _ => raise ArgumentCount }
      self.acc = v
      self.stack = stack
      self.next = Return
    }
    _ => raise CallNonProcedure
  }
}

///|
pub fn run_to_halt(self : VM) -> Unit!SchemeException {
  for {
    match (self.next, self.stack) {
      (Return, None) => break
      _ => self.run_one_step!()
    }
  }
}
