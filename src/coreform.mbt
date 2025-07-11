///|
impl Default for CoreForm with default() {
  SelfEval(Nil)
}

///|
pub impl ToSexp for CoreForm with to_sexp(self) {
  let s = Value::symbol
  match self {
    SelfEval(v) => v
    Var(name) => Symbol(name)
    Quote(v) => to_sexp([s("quote"), v])
    Lambda(parms, Begin(bodys, bodye), ..) =>
      to_sexp((s("lambda"), (parms, [..bodys, bodye])))
    Lambda(parms, body, ..) => //
      to_sexp((s("lambda"), (parms, (body, Nil))))
    Begin(es, ee) => to_sexp((s("begin"), [..es, ee]))
    If(e1, e2, Some(e3)) => to_sexp((s("if"), [e1, e2, e3]))
    If(e1, e2, None) => to_sexp((s("if"), [e1, e2]))
    Apply(f, args) => to_sexp((f, args))
    Set(name, e) => to_sexp((s("set!"), (name, [e])))
    Define(name, e) => to_sexp((s("define"), (name, [e])))
  }
}

///|
pub impl FromSexp for CoreForm with from_sexp(self) {
  self.to_core_form()
}

///|
pub fn Value::to_core_form(self : Value) -> CoreForm raise FromSexpError {
  let to_quote = fn(r) raise FromSexpError {
    match r {
      Pair(r1, Nil) => Quote(r1)
      _ => raise FromSexpError(self)
    }
  }
  let to_if = fn(r) raise FromSexpError {
    match r {
      Pair(e1, Pair(e2, Nil)) => If(e1.to_core_form(), e2.to_core_form(), None)
      Pair(e1, Pair(e2, Pair(e3, Nil))) =>
        If(e1.to_core_form(), e2.to_core_form(), Some(e3.to_core_form()))
      _ => raise FromSexpError(self)
    }
  }
  let to_set = fn(r) -> CoreForm raise FromSexpError {
    match r {
      Pair(Symbol(name), Pair(e1, Nil)) => Set(name, e1.to_core_form())
      _ => raise FromSexpError(self)
    }
  }
  let to_define = fn(r) -> CoreForm raise FromSexpError {
    loop r {
      Pair(Pair(fname, parms), bodys) =>
        continue Pair(
            fname,
            Pair(Pair(Value::symbol("lambda"), Pair(parms, bodys)), Nil),
          )
      Pair(Symbol(name), Pair(e1, Nil)) => Define(name, e1.to_core_form())
      _ => raise FromSexpError(self)
    }
  }
  let proper_list_length = fn(ls : Value) raise FromSexpError {
    guard ls.list_tail_and_length() is (Nil, length) else {
      raise FromSexpError(self)
    }
    length
  }
  let to_seq = fn(r) raise FromSexpError {
    let length = proper_list_length(r)
    guard length > 0 else { raise FromSexpError(self) }
    guard to_core_from_list(r, length - 1) is (bodys, Pair(bodye, _))
    Begin(bodys, bodye.to_core_form())
  }
  let to_lambda = fn(r) raise FromSexpError {
    guard r is Pair(parms_list, bodys) else { raise FromSexpError(self) }
    let parms = {
      let length = proper_list_length(parms_list)
      let res = FixedArray::make(length, Symbol::default())
      loop (0, parms_list) {
        (i, Pair(Symbol(s), r)) => {
          for i in 0..<i {
            if res[i] == s {
              raise FromSexpError(self)
            }
          }
          res[i] = s
          continue (i + 1, r)
        }
        (_, Nil) => ()
        _ => panic()
      }
      res
    }
    Lambda(parms, to_seq(bodys), name=None)
  }
  let to_args = fn(r) raise FromSexpError {
    let length = proper_list_length(r)
    to_core_from_list(r, length).0
  }
  match self.expand() {
    Symbol(s) => Var(s)
    Pair(l, r) =>
      match l {
        Symbol(s) =>
          match s.to_string() {
            "quote" => to_quote(r)
            "lambda" => to_lambda(r)
            "begin" => to_seq(r)
            "if" => to_if(r)
            "set!" => to_set(r)
            "define" => to_define(r)
            _ => Apply(Var(s), to_args(r))
          }
        _ => Apply(l.to_core_form(), to_args(r))
      }
    Int(_) | Double(_) | True | False | String(_) as e => SelfEval(e)
    _ => raise FromSexpError(self)
  }
}

///|
fn to_core_from_list(
  ls : Value,
  length : Int
) -> (FixedArray[CoreForm], Value) raise FromSexpError {
  let dist = FixedArray::make(length, CoreForm::default())
  for i = 0, r = ls; i < length; {
    guard r is Pair(l, r)
    dist[i] = l.to_core_form()
    continue i + 1, r
  } else {
    (dist, r)
  }
}

///|
fn Value::expand(self : Value) -> Value raise FromSexpError {
  let exp = self
  letrec expand_let = fn(body) raise FromSexpError {
    guard body is Pair(nvs, body) else { raise FromSexpError(exp) }
    fn split(nvs) raise FromSexpError {
      match nvs {
        Pair(Pair(n, Pair(v, Nil)), r) => {
          let (ns, vs) = split(r)
          (Pair(n, ns), Pair(v, vs))
        }
        Nil => (Nil, Nil)
        _ => raise FromSexpError(exp)
      }
    }

    let (names, values) = split(nvs)
    let lam = Pair(Value::symbol("lambda"), Pair(names, body))
    Pair(lam, values)
  }
  and expand_cond = fn(body) raise FromSexpError {
    fn expand_clauses(r) raise FromSexpError {
      match r {
        Pair(Pair(pred, Pair(texp, Nil)), r) => {
          let e = if pred is Symbol(s) && s.to_string() == "else" {
            guard r is Nil else { raise FromSexpError(exp) }
            texp
          } else {
            Pair(Value::symbol("if"), Pair(pred, Pair(texp, expand_clauses(r))))
          }
          Pair(e, Nil)
        }
        Nil => Nil
        _ => raise FromSexpError(exp)
      }
    }

    match expand_clauses(body) {
      Pair(e, Nil) => e
      _ => raise FromSexpError(exp)
    }
  }
  and expand_and = fn(body) raise FromSexpError {
    match body {
      Nil => True
      Pair(l, Nil) => l
      Pair(l, r) =>
        Value::list([
          Value::symbol("if"),
          l,
          Pair(Value::symbol("and"), r),
          False,
        ])
      _ => raise FromSexpError(exp)
    }
  }
  and expand_or = fn(body) raise FromSexpError {
    match body {
      Nil => False
      Pair(l, Nil) => l
      Pair(l, r) => {
        let var_l = Symbol(Symbol::of("$GEN_SYM"))
        Value::list([
          Value::symbol("let"),
          Value::list([Value::list([var_l, l])]),
          Value::list([
            Value::symbol("if"),
            var_l,
            var_l,
            Pair(Value::symbol("or"), r),
          ]),
        ])
      }
      _ => raise FromSexpError(exp)
    }
  }

  loop exp {
    Pair(Symbol(s), body) as e =>
      match s.to_string() {
        "let" => continue expand_let(body)
        "cond" => continue expand_cond(body)
        "and" => continue expand_and(body)
        "or" => continue expand_or(body)
        _ => e
      }
    e => e
  }
}
