///|
#as_free_fn
pub fn CoreForm::compile(self : CoreForm) -> Inst {
  fn then(exp, next) {
    match exp {
      SelfEval(v) | Quote(v) => Const(v, next)
      Var(name) => Refer(name, next)
      Lambda(parm_names, body) => {
        let body = then(body, Return)
        let name = match next {
          Define(name, _) | Set(name, _) => Some(name)
          _ => None
        }
        Close(parm_names, body, name, next)
      }
      Begin(bodys, bodye) => {
        let bodyei = then(bodye, next)
        bodys.rev_fold(init=bodyei, (acc, x) => then(x, acc))
      }
      If(ep, et, ef) => {
        let eti = then(et, next)
        let efi = match ef {
          Some(ef) => then(ef, next)
          None => next
        }
        then(ep, Branch(eti, efi))
      }
      Apply(f, args) => {
        let length = args.length()
        let fi = then(f, Apply)
        let argsi = Args(
          length,
          args.rev_foldi(init=fi, (i, acc, x) => then(
            x,
            Push(length - 1 - i, acc),
          )),
        )
        match next {
          Return => argsi
          _ => Save(argsi, next)
        }
      }
      Set(name, e) => then(e, Set(name, next))
      Define(name, e) => then(e, Define(name, next))
    }
  }

  then(self, Return)
}
