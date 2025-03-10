///|
fn add_primitive_from_map[A](
  self : Environment,
  m : Map[String, A],
  f : (Symbol, A) -> Primitive
) -> Unit {
  for k, v in m {
    let s = Symbol::of(k)
    self.binds[s] = Primitive(f(s, v))
  }
}

///|
pub fn add_primitive_1_from_map(
  self : Environment,
  m : Map[String, (Value) -> Value!SchemeException]
) -> Unit {
  self.add_primitive_from_map(m, fn(name, f1) {
    Normal(name~, fn {
      [v1] => f1!(v1)
      _ => raise ArgumentCount
    })
  })
}

///|
pub fn add_primitive_2_from_map(
  self : Environment,
  m : Map[String, (Value, Value) -> Value!SchemeException]
) -> Unit {
  self.add_primitive_from_map(m, fn(name, f2) {
    Normal(name~, fn {
      [v1, v2] => f2!(v1, v2)
      _ => raise ArgumentCount
    })
  })
}

///|
pub fn add_primitive_3_from_map(
  self : Environment,
  m : Map[String, (Value, Value, Value) -> Value!SchemeException]
) -> Unit {
  self.add_primitive_from_map(m, fn(name, f3) {
    Normal(name~, fn {
      [v1, v2, v3] => f3!(v1, v2, v3)
      _ => raise ArgumentCount
    })
  })
}

///|
pub fn add_primitive_n_from_map(
  self : Environment,
  m : Map[String, (FixedArray[Value]) -> Value!SchemeException]
) -> Unit {
  self.add_primitive_from_map(m, fn(name, f) { Normal(name~, f) })
}

///|
/// `number?`
/// 
/// `+`, `-`, `*`, `/`
/// 
/// `=`, `>`, `<`
pub fn add_number_primitive(self : Environment) -> Unit {
  self.add_primitive_1_from_map({
    "number?": fn {
      Int(_) | Double(_) => True
      _ => False
    },
  })
  self.add_primitive_2_from_map({
    "=": fn {
      Int(a), Int(b) => Value::bool(a == b)
      Double(a), Double(b) => Value::bool(a == b)
      Double(a), Int(b) => Value::bool(a == b.to_double())
      Int(b), Double(a) => Value::bool(a == b.to_double())
      Int(_) | Double(_), _ => raise TypeError(1)
      _, _ => raise TypeError(0)
    },
    ">": fn {
      Int(a), Int(b) => Value::bool(a > b)
      Double(a), Double(b) => Value::bool(a > b)
      Double(a), Int(b) => Value::bool(a > b.to_double())
      Int(b), Double(a) => Value::bool(a > b.to_double())
      Int(_) | Double(_), _ => raise TypeError(1)
      _, _ => raise TypeError(0)
    },
    "<": fn {
      Int(a), Int(b) => Value::bool(a < b)
      Double(a), Double(b) => Value::bool(a < b)
      Double(a), Int(b) => Value::bool(a < b.to_double())
      Int(b), Double(a) => Value::bool(a < b.to_double())
      Int(_) | Double(_), _ => raise TypeError(1)
      _, _ => raise TypeError(0)
    },
  })
  fn fold_args_d(
    args : FixedArray[Value],
    i : Int,
    init : Double,
    fdd : (Double, Double) -> Double
  ) -> _!SchemeException {
    let mut accd = init
    for i = i; i < args.length(); i = i + 1 {
      accd = fdd(
        accd,
        match args[i] {
          Int(x) => x.to_double()
          Double(x) => x
          _ => raise TypeError(i)
        },
      )
    }
    Double(accd)
  }

  fn fold_args_i(
    args : FixedArray[Value],
    i : Int,
    init : Int,
    fii : (Int, Int) -> Int,
    fdd : (Double, Double) -> Double
  ) -> _!SchemeException {
    let mut acci = init
    for i = i; i < args.length(); i = i + 1 {
      match args[i] {
        Int(x) => acci = fii(acci, x)
        Double(x) =>
          return fold_args_d!(args, i + 1, fdd(acci.to_double(), x), fdd)
        _ => raise TypeError(i)
      }
    }
    Int(acci)
  }

  self.add_primitive_n_from_map({
    "+": fn { args => fold_args_i!(args, 0, 0, Int::op_add, Double::op_add) },
    "-": fn {
      [] => raise ArgumentCount
      [Int(arg0)] => Int(Int::op_neg(arg0))
      [Double(arg0)] => Double(Double::op_neg(arg0))
      [Int(arg0), ..] as args =>
        fold_args_i!(args, 1, arg0, Int::op_sub, Double::op_sub)
      [Double(arg0), ..] as args => fold_args_d!(args, 1, arg0, Double::op_sub)
      _ => raise TypeError(0)
    },
    "*": fn { args => fold_args_i!(args, 0, 1, Int::op_mul, Double::op_mul) },
    "/": fn {
      [] => raise ArgumentCount
      [Int(arg0)] => Int(Int::op_div(1, arg0))
      [Double(arg0)] => Double(Double::op_div(1, arg0))
      [Int(arg0), ..] as args =>
        fold_args_i!(args, 1, arg0, Int::op_div, Double::op_div)
      [Double(arg0), ..] as args => fold_args_d!(args, 1, arg0, Double::op_div)
      _ => raise TypeError(0)
    },
  })
}

///|
/// `cons`, `car`, `cdr`
/// 
/// `null?`, `pair?`
pub fn add_pair_primitive(self : Environment) -> Unit {
  self.add_primitive_1_from_map({
    "car": fn {
      Pair(l, _) => l
      _ => raise TypeError(0)
    },
    "cdr": fn {
      Pair(_, r) => r
      _ => raise TypeError(0)
    },
    "null?": fn {
      Nil => True
      _ => False
    },
    "pair?": fn {
      Pair(_) => True
      _ => False
    },
  })
  self.add_primitive_2_from_map({ "cons": fn { l, r => Pair(l, r) } })
  self.add_primitive_n_from_map({ "list": fn { args => Value::list(args) } })
}

///|
/// `string?`, `string-append`, `string->symbol`
/// 
/// `symbol->string`, `number->string`, `value->string`
pub fn add_string_primitive(self : Environment) -> Unit {
  self.add_primitive_1_from_map({
    "string?": fn {
      String(_) => True
      _ => False
    },
    "string->symbol": fn {
      String(s) => Value::symbol(s)
      _ => raise TypeError(0)
    },
    "symbol->string": fn {
      Symbol(x) => String(x.to_string())
      _ => raise TypeError(0)
    },
    "number->string": fn {
      Int(x) => String(x.to_string())
      Double(x) => String(x.to_string())
      _ => raise TypeError(0)
    },
    "value->string": fn { x => String(x.to_string()) },
  })
  self.add_primitive_n_from_map({
    "string-append": fn {
      args => {
        let b = StringBuilder::new()
        for i, v in args {
          guard v is String(str) else { raise TypeError(i) }
          b.write_string(str)
        }
        String(b.to_string())
      }
    },
  })
}

///|
/// `vector`, `vector?`, `make-vector`, `vector-length`
/// 
/// `vector-ref`, `vector-set!`
pub fn add_vector_primitive(self : Environment) -> Unit {
  fn make_vector(n, init) -> _!SchemeException {
    guard n is Int(n) else { raise TypeError(0) }
    guard n >= 0 else { raise InvalidArgument(0) }
    Vector(FixedArray::make(n, init))
  }

  self.add_primitive_1_from_map({
    "vector?": fn {
      Vector(_) => True
      _ => False
    },
    "vector-length": fn {
      Vector(v) => Int(v.length())
      _ => raise TypeError(0)
    },
  })
  self.add_primitive_2_from_map({
    "vector-ref": fn {
      Vector(v), Int(i) => {
        guard 0 <= i && i < v.length() else { raise InvalidArgument(1) }
        v.unsafe_get(i)
      }
      Vector(_), _ => raise InvalidArgument(1)
      _, _ => raise TypeError(0)
    },
  })
  self.add_primitive_3_from_map({
    "vector-set!": fn {
      Vector(v), Int(i), x => {
        guard 0 <= i && i < v.length() else { raise InvalidArgument(1) }
        v[i] = x
        Value::default()
      }
      Vector(_), _, _ => raise InvalidArgument(1)
      _, _, _ => raise TypeError(0)
    },
  })
  self.add_primitive_n_from_map({
    "vector": fn { args => Vector(args) },
    "make-vector": fn {
      [n] => make_vector!(n, Int(0))
      [n, init] => make_vector!(n, init)
      _ => raise ArgumentCount
    },
  })
}

///|
/// `eq?`, `symbol?`, `call/cc`, `apply`
pub fn add_other_primitive(self : Environment) -> Unit {
  for p in [CallCC, Apply] {
    self.binds[p.name()] = Primitive(p)
  }
  self.add_primitive_1_from_map({
    "symbol?": fn {
      Symbol(_) => True
      _ => False
    },
    "procedure?": fn {
      Primitive(_) | Closure(_) | Continuation(_) => True
      _ => False
    },
  })
  self.add_primitive_2_from_map({ "eq?": fn { a, b => Value::bool(eq(a, b)) } })
}

///|
pub fn add_all_base_primitive(self : Environment) -> Unit {
  self
  ..add_number_primitive()
  ..add_pair_primitive()
  ..add_string_primitive()
  ..add_vector_primitive()
  .add_other_primitive()
}
