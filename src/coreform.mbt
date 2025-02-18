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
    Quote(v) => [s("quote"), v].to_sexp()
    Lambda(parms, Begin(bodys, bodye), ..) =>
      (s("lambda"), (parms, [..bodys, bodye])).to_sexp()
    Lambda(parms, body, ..) => //
      (s("lambda"), (parms, (body, Nil))).to_sexp()
    Begin(es, ee) => (s("begin"), [..es, ee]).to_sexp()
    If(e1, e2, Some(e3)) => (s("if"), [e1, e2, e3]).to_sexp()
    If(e1, e2, None) => (s("if"), [e1, e2]).to_sexp()
    Apply(f, args) => (f, args).to_sexp()
    Set(name, e) => (s("set!"), (name, [e])).to_sexp()
    Define(name, e) => (s("define"), (name, [e])).to_sexp()
  }
}

///|
pub impl FromSexp for CoreForm with from_sexp(self) {
  to_core_form!(self)
}

///|
pub fn to_core_form(self : Value) -> CoreForm!FromSexpError {
  let exp = self
  fn go() -> CoreForm!FromSexpError {
    match expand!(exp) {
      Symbol(s) => Var(s)
      Pair(l, r) =>
        match l {
          Symbol(s) =>
            match s.to_string() {
              "quote" => to_quote!(r)
              "lambda" => to_lambda!(r)
              "begin" => to_seq!(r)
              "if" => to_if!(r)
              "set!" => to_set!(r)
              "define" => to_define!(r)
              _ => Apply(Var(s), to_args!(r))
            }
          _ => Apply(to_core_form!(l), to_args!(r))
        }
      Int(_) | Double(_) | True | False | String(_) as e => SelfEval(e)
      _ => raise FromSexpError(exp)
    }
  }

  fn to_quote(r) -> _!FromSexpError {
    match r {
      Pair(r1, Nil) => Quote(r1)
      _ => raise FromSexpError(exp)
    }
  }

  fn to_lambda(r) -> _!FromSexpError {
    guard let Pair(parms, bodys) = r else { _ => raise FromSexpError(exp) }
    let parms = valid_parms!(parms)
    Lambda(parms, to_seq!(bodys), name=None)
  }

  fn valid_parms(parms) -> _!FromSexpError {
    let length = proper_list_length!(parms)
    let res = FixedArray::make(length, Symbol::default())
    loop 0, parms {
      i, Pair(Symbol(s), r) => {
        for i in 0..<i {
          if res[i] == s {
            raise FromSexpError(exp)
          }
        }
        res[i] = s
        continue i + 1, r
      }
      _, Nil => ()
      _, _ => panic()
    }
    res
  }

  fn to_seq(r) -> _!FromSexpError {
    let length = proper_list_length!(r)
    if length == 0 {
      raise FromSexpError(exp)
    }
    guard let (bodys, Pair(bodye, _)) = to_core_from_list!(r, length - 1)
    Begin(bodys, to_core_form!(bodye))
  }

  fn to_if(r) -> _!FromSexpError {
    match r {
      Pair(e1, Pair(e2, Nil)) => If(to_core_form!(e1), to_core_form!(e2), None)
      Pair(e1, Pair(e2, Pair(e3, Nil))) =>
        If(to_core_form!(e1), to_core_form!(e2), Some(to_core_form!(e3)))
      _ => raise FromSexpError(exp)
    }
  }

  fn to_set(r) -> _!FromSexpError {
    match r {
      Pair(Symbol(name), Pair(e1, Nil)) => Set(name, to_core_form!(e1))
      _ => raise FromSexpError(exp)
    }
  }

  fn to_define(r) -> _!FromSexpError {
    match r {
      Pair(Pair(fname, parms), bodys) =>
        to_define!(
          Pair(
            fname,
            Pair(Pair(Value::symbol("lambda"), Pair(parms, bodys)), Nil),
          ),
        )
      Pair(Symbol(name), Pair(e1, Nil)) => Define(name, to_core_form!(e1))
      _ => raise FromSexpError(exp)
    }
  }

  fn to_args(r) -> _!FromSexpError {
    let length = proper_list_length!(r)
    to_core_from_list!(r, length).0
  }

  fn proper_list_length(ls) -> _!FromSexpError {
    guard let (Nil, length) = list_tail_and_length(ls) else {
      _ => raise FromSexpError(exp)
    }
    length
  }

  go!()
}

///|
fn to_core_from_list(
  ls : Value,
  length : Int
) -> (FixedArray[CoreForm], Value)!FromSexpError {
  let dist = FixedArray::make(length, CoreForm::default())
  for i = 0, r = ls; i < length; {
    guard let Pair(l, r) = r
    dist[i] = to_core_form!(l)
    continue i + 1, r
  } else {
    (dist, r)
  }
}

///|
fn expand(self : Value) -> Value!FromSexpError {
  let exp = self
  fn go!() -> _!FromSexpError {
    loop exp {
      Pair(Symbol(s), body) as e =>
        match s.to_string() {
          "let" => continue expand_let!(body)
          "cond" => continue expand_cond!(body)
          "and" => continue expand_and!(body)
          "or" => continue expand_or!(body)
          _ => e
        }
      e => e
    }
  }

  fn expand_let(body) -> _!FromSexpError {
    guard let Pair(nvs, body) = body else { _ => raise FromSexpError(exp) }
    fn split(nvs) -> (Value, Value)!FromSexpError {
      match nvs {
        Pair(Pair(n, Pair(v, Nil)), r) => {
          let (ns, vs) = split!(r)
          (Pair(n, ns), Pair(v, vs))
        }
        Nil => (Nil, Nil)
        _ => raise FromSexpError(exp)
      }
    }

    let (names, values) = split!(nvs)
    let lam = Pair(Value::symbol("lambda"), Pair(names, body))
    Pair(lam, values)
  }

  fn expand_cond(body) -> _!FromSexpError {
    fn expand_clauses(r) -> Value!FromSexpError {
      match r {
        Pair(Pair(pred, Pair(texp, Nil)), r) => {
          let e = if pred is Symbol(s) && s.to_string() == "else" {
            guard let Nil = r else { _ => raise FromSexpError(exp) }
            texp
          } else {
            Pair(
              Value::symbol("if"),
              Pair(pred, Pair(texp, expand_clauses!(r))),
            )
          }
          Pair(e, Nil)
        }
        Nil => Nil
        _ => raise FromSexpError(exp)
      }
    }

    match expand_clauses!(body) {
      Pair(e, Nil) => e
      _ => raise FromSexpError(exp)
    }
  }

  fn expand_and(body) -> _!FromSexpError {
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

  fn expand_or(body) -> _!FromSexpError {
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

  go!()
}
