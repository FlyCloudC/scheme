///|
fn type_error(name : String) -> SchemeException {
  TypeError(Some(Symbol::of(name)))
}

///|
fn add_p_1(
  self : Environment,
  m : Map[String, (Value) -> Value!SchemeException]
) -> Unit {
  let binds = self.binds
  for name, f in m {
    let name = Symbol::of(name)
    binds[name] = Primitive({
      name,
      body: fn {
        [a] => f!(a)
        _ => raise ArgumentCount(Some(name))
      },
    })
  }
}

///|
fn add_p_2(
  self : Environment,
  m : Map[String, (Value, Value) -> Value!SchemeException]
) -> Unit {
  let binds = self.binds
  for name, f in m {
    let name = Symbol::of(name)
    binds[name] = Primitive({
      name,
      body: fn {
        [a, b] => f!(a, b)
        _ => raise ArgumentCount(Some(name))
      },
    })
  }
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
      _ => raise type_error("~-")
    },
  })
  self.add_p_2({
    "+": fn {
      Int(a), Int(b) => Int(a + b)
      Double(a), Double(b) => Double(a + b)
      Double(a), Int(b) => Double(a + b.to_double())
      Int(b), Double(a) => Double(a + b.to_double())
      _, _ => raise type_error("+")
    },
    "-": fn {
      Int(a), Int(b) => Int(a - b)
      Double(a), Double(b) => Double(a - b)
      Double(a), Int(b) => Double(a - b.to_double())
      Int(b), Double(a) => Double(a - b.to_double())
      _, _ => raise type_error("-")
    },
    "*": fn {
      Int(a), Int(b) => Int(a * b)
      Double(a), Double(b) => Double(a * b)
      Double(a), Int(b) => Double(a * b.to_double())
      Int(b), Double(a) => Double(a * b.to_double())
      _, _ => raise type_error("*")
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
      _, _ => raise type_error("/")
    },
    "=": fn {
      Int(a), Int(b) => Value::bool(a == b)
      Double(a), Double(b) => Value::bool(a == b)
      Double(a), Int(b) => Value::bool(a == b.to_double())
      Int(b), Double(a) => Value::bool(a == b.to_double())
      _, _ => raise type_error("=")
    },
    ">": fn {
      Int(a), Int(b) => Value::bool(a > b)
      Double(a), Double(b) => Value::bool(a > b)
      Double(a), Int(b) => Value::bool(a > b.to_double())
      Int(b), Double(a) => Value::bool(a > b.to_double())
      _, _ => raise type_error(">")
    },
    "<": fn {
      Int(a), Int(b) => Value::bool(a < b)
      Double(a), Double(b) => Value::bool(a < b)
      Double(a), Int(b) => Value::bool(a < b.to_double())
      Int(b), Double(a) => Value::bool(a < b.to_double())
      _, _ => raise type_error("<")
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
      _ => raise type_error("car")
    },
    "cdr": fn {
      Pair(_, r) => r
      _ => raise type_error("cdr")
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
}

///|
// pub fn add_string_primitive(self : Environment) -> Unit {

// }

///|
// pub fn add_vector_primitive(self : Environment) -> Unit {

// }

///|
/// `eq?`
pub fn add_base_primitive(self : Environment) -> Unit {
  self.add_p_2({ "eq?": fn { a, b => Value::bool(eq(a, b)) } })
}
