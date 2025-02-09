///|
pub fn compile(self : CoreForm) -> Inst {
  analyze(self, Return)
}

///|
fn analyze(self : CoreForm, next : Inst) -> Inst {
  match self {
    SelfEval(v) | Quote(v) => Const(v, next)
    Var(name) => Refer(name, next)
    Lambda(parm_names, body, ..) => {
      let body = analyze(body, Return)
      let name = match next {
        Define(name, _) | Set(name, _) => Some(name)
        _ => None
      }
      Close(parm_names, body, name, next)
    }
    Begin(bodys, bodye) => {
      let bodyei = analyze(bodye, next)
      bodys.rev_fold(init=bodyei, fn { acc, x => analyze(x, acc) })
    }
    If(ep, et, ef) => {
      let eti = analyze(et, next)
      let efi = match ef {
        Some(ef) => analyze(ef, next)
        None => Const(Value::default(), next)
      }
      analyze(ep, Branch(eti, efi))
    }
    Apply(f, args) => {
      let length = args.length()
      let fi = analyze(f, Apply)
      let argsi = Args(
        length,
        args.rev_foldi(init=fi, fn {
          i, acc, x => analyze(x, Push(length - 1 - i, acc))
        }),
      )
      match next {
        Return => argsi
        _ => Save(argsi, next)
      }
    }
    Set(name, e) => analyze(e, Set(name, next))
    Define(name, e) => analyze(e, Define(name, next))
  }
}
