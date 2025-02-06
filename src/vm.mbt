///|
pub fn VM::new(next : Inst, env : Environment) -> VM {
  { //
    acc: Value::default(),
    next,
    env,
    rib: [],
    stack: None,
  }
}

///|
pub fn run_one_step(self : VM) -> Unit!SchemeException {
  match self.next {
    Halt => ()
    Const(v, next) => {
      self.acc = v
      self.next = next
    }
    Refer(name, next) => {
      self.acc = self.env.lookup!(name)
      self.next = next
    }
    Return => {
      let saved_frame = self.stack.unwrap()
      self.next = saved_frame.ret
      self.env = saved_frame.env
      self.rib = saved_frame.rib
      self.stack = saved_frame.stack
    }
    Close(make_closure, next) => {
      self.acc = Closure(make_closure(self.env))
      self.next = next
    }
    Branch(nt, nf) =>
      self.next = match self.acc {
        True => nt
        _ => nf
      }
    Frame(args_length, ret, next) => {
      self.stack = Some({ ret, env: self.env, rib: self.rib, stack: self.stack })
      self.rib = FixedArray::make(args_length, Value::default())
      self.next = next
    }
    Arg(i, next) => {
      self.rib[i] = self.acc
      self.next = next
    }
    Apply =>
      match self.acc {
        Closure(clo) => {
          guard self.rib.length() == clo.parm_names.length() else {
            raise ArgumentCount(clo.name)
          }
          self.next = clo.body
          self.env = clo.env.extend(clo.parm_names, self.rib, clo)
        }
        Primitive({ body, .. }) => {
          self.acc = body!(self.rib)
          self.next = Return
        }
        v => raise CallNonProcedure(v)
      }
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
pub fn run_to_halt(self : VM) -> Unit!SchemeException {
  loop self.next {
    Halt => break
    _ => {
      self.run_one_step!()
      continue self.next
    }
  }
}
