///|
fn add_primitives[A](
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
fn add_p_1(
  self : Environment,
  m : Map[String, (Value) -> Value!SchemeException]
) -> Unit {
  self.add_primitives(m, fn(name, f1) {
    Normal(name~, fn {
      [v1] => f1!(v1)
      _ => raise ArgumentCount
    })
  })
}

///|
fn add_p_2(
  self : Environment,
  m : Map[String, (Value, Value) -> Value!SchemeException]
) -> Unit {
  self.add_primitives(m, fn(name, f2) {
    Normal(name~, fn {
      [v1, v2] => f2!(v1, v2)
      _ => raise ArgumentCount
    })
  })
}

///|
fn add_p_3(
  self : Environment,
  m : Map[String, (Value, Value, Value) -> Value!SchemeException]
) -> Unit {
  self.add_primitives(m, fn(name, f3) {
    Normal(name~, fn {
      [v1, v2, v3] => f3!(v1, v2, v3)
      _ => raise ArgumentCount
    })
  })
}

///|
fn add_p_n(
  self : Environment,
  m : Map[String, (FixedArray[Value]) -> Value!SchemeException]
) -> Unit {
  self.add_primitives(m, fn(name, f) { Normal(name~, fn(args) { f!(args) }) })
}

///|
/// `number?`
/// 
/// `~-` (minus by 0)
/// 
/// `+`, `-`, `*`, `/`
/// 
/// `=`, `>`, `<`
pub fn add_number_primitive(self : Environment) -> Unit {
  self.add_p_1({
    "number?": fn {
      Int(_) | Double(_) => True
      _ => False
    },
    "~-": fn {
      Int(a) => Int(-a)
      Double(a) => Double(-a)
      _ => raise TypeError(0)
    },
  })
  self.add_p_2({
    "+": fn {
      Int(a), Int(b) => Int(a + b)
      Double(a), Double(b) => Double(a + b)
      Double(a), Int(b) => Double(a + b.to_double())
      Int(b), Double(a) => Double(a + b.to_double())
      Int(_) | Double(_), _ => raise TypeError(1)
      _, _ => raise TypeError(0)
    },
    "-": fn {
      Int(a), Int(b) => Int(a - b)
      Double(a), Double(b) => Double(a - b)
      Double(a), Int(b) => Double(a - b.to_double())
      Int(b), Double(a) => Double(a - b.to_double())
      Int(_) | Double(_), _ => raise TypeError(1)
      _, _ => raise TypeError(0)
    },
    "*": fn {
      Int(a), Int(b) => Int(a * b)
      Double(a), Double(b) => Double(a * b)
      Double(a), Int(b) => Double(a * b.to_double())
      Int(b), Double(a) => Double(a * b.to_double())
      Int(_) | Double(_), _ => raise TypeError(1)
      _, _ => raise TypeError(0)
    },
    "/": fn {
      Int(a), Int(b) => {
        guard b != 0 else { raise DevideZero }
        if a % b == 0 {
          Int(a / b)
        } else {
          Double(a.to_double() / b.to_double())
        }
      }
      Double(a), Double(b) => Double(a / b)
      Double(a), Int(b) => Double(a / b.to_double())
      Int(b), Double(a) => Double(a / b.to_double())
      Int(_) | Double(_), _ => raise TypeError(1)
      _, _ => raise TypeError(0)
    },
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
}

///|
/// `cons`, `car`, `cdr`
/// 
/// `null?`, `pair?`
pub fn add_pair_primitive(self : Environment) -> Unit {
  self.add_p_1({
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
  self.add_p_2({ "cons": fn { l, r => Pair(l, r) } })
  self.add_p_n({ "list": fn { args => Value::list(args) } })
}

///|
// pub fn add_string_primitive(self : Environment) -> Unit {

// }

///|
/// `vector`, `vector?`, `make-vector`, `vector-length`
/// 
/// `vector-ref`, `vector-set!`
pub fn add_vector_primitive(self : Environment) -> Unit {
  fn make_vector(n, init) -> _!SchemeException {
    guard let Int(n) = n else { _ => raise TypeError(0) }
    guard n >= 0 else { raise InvalidArgument(0) }
    Vector(FixedArray::make(n, init))
  }

  self.add_p_1({
    "vector?": fn {
      Vector(_) => True
      _ => False
    },
    "vector-length": fn {
      Vector(v) => Int(v.length())
      _ => raise TypeError(0)
    },
  })
  self.add_p_2({
    "vector-ref": fn {
      Vector(v), Int(i) => {
        guard 0 <= i && i < v.length() else { raise InvalidArgument(1) }
        v.unsafe_get(i)
      }
      Vector(_), _ => raise InvalidArgument(1)
      _, _ => raise TypeError(0)
    },
  })
  self.add_p_3({
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
  self.add_p_n({
    "vector": fn { args => Vector(args) },
    "make-vector": fn {
      [n] => make_vector!(n, Int(0))
      [n, init] => make_vector!(n, init)
      _ => raise ArgumentCount
    },
  })
}

///|
/// `eq?`, `call/cc`
pub fn add_base_primitive(self : Environment) -> Unit {
  self.add_p_2({ "eq?": fn { a, b => Value::bool(eq(a, b)) } })
  self.binds[CallCC.name()] = Primitive(CallCC)
}
