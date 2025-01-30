///|
pub fn analyze(self : CoreForm) -> async (Environment) -> Value!SchemeException {
  analyze_with_name(self)
}

///|
pub fn analyze_with_name(
  self : CoreForm,
  name? : Symbol
) -> async (Environment) -> Value!SchemeException {
  match self {
    SelfEval(v) | Quote(v) => fn(_) { v }
    Var(name) => fn(env) { env.lookup!(name) }
    Lambda(var_names, body, ..) => {
      let body = analyze(body)
      fn(env) { Closure({ env, parm_names: var_names, body, name }) }
    }
    Begin(bodys, bodye) => {
      let bodysi = bodys.map(analyze)
      let bodyei = analyze_with_name(bodye, name?)
      fn(env) {
        for ei in bodysi {
          ei!!(env) |> ignore
        }
        bodyei!!(env)
      }
    }
    If(ep, et, ef) => {
      let epi = analyze(ep)
      let eti = analyze_with_name(et, name?)
      let efi = match ef {
        Some(ef) => analyze_with_name(ef, name?)
        None => fn(_) { Nil }
      }
      fn(env) {
        match epi!!(env) {
          False => efi!!(env)
          _ => eti!!(env)
        }
      }
    }
    Apply(f, args) => {
      let fi = analyze(f)
      let argsi = args.map(analyze)
      let length = args.length()
      fn(env) {
        let values = FixedArray::make(length, Nil)
        for i in 0..<length {
          values[i] = argsi[i]!!(env)
        }
        match fi!!(env) {
          Closure({ env: saved_env, parm_names, body, name } as closure) => {
            guard length == parm_names.length() else {
              raise ArgumentCount(name)
            }
            body!!(saved_env.extend(parm_names, values, closure))
          }
          Primitive({ body, .. }) => body!(values)
          v => raise CallNonProcedure(v)
        }
      }
    }
    Set(name, e) => {
      let ei = analyze(e)
      fn(env) {
        env.set_var!(name, ei!!(env))
        Value::default()
      }
    }
    Define(name, e) => {
      let ei = analyze_with_name(e, name~)
      fn(env) {
        env.define_var(name, ei!!(env))
        Value::default()
      }
    }
  }
}
