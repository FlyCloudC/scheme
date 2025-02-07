///|
pub fn compile(self : CoreForm) -> Inst {
  analyze(self, Halt)
}

///|
fn analyze(self : CoreForm, next : Inst) -> Inst {
  analyze_with_name(self, next)
}

///|
fn analyze_with_name(self : CoreForm, next : Inst, name? : Symbol) -> Inst {
  match self {
    SelfEval(v) | Quote(v) => Const(v, next)
    Var(name) => Refer(name, next)
    Lambda(parm_names, body, ..) => {
      let body = analyze(body, Return)
      Close(fn(env) { { env, parm_names, body, name } }, next)
    }
    Begin(bodys, bodye) => {
      let bodyei = analyze_with_name(bodye, next, name?)
      bodys.rev_fold(init=bodyei, fn { acc, x => analyze(x, acc) })
    }
    If(ep, et, ef) => {
      let eti = analyze_with_name(et, next, name?)
      let efi = match ef {
        Some(ef) => analyze_with_name(ef, next, name?)
        None => Const(Value::default(), next)
      }
      analyze(ep, Branch(eti, efi))
    }
    Apply(f, args) => {
      let length = args.length()
      let fi = analyze(f, Apply)
      let argsi = args.rev_foldi(init=fi, fn {
        i, acc, x => analyze(x, Arg(length - 1 - i, acc))
      })
      Frame(length, next, argsi)
    }
    Set(name, e) => analyze(e, Set(name, next))
    Define(name, e) => analyze_with_name(e, Define(name, next), name~)
  }
}
