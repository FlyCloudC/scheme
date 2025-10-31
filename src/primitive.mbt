///|
fn prim_iter_from_map(
  m : Map[String, (FixedArray[Value]) -> Value raise SchemeException],
) -> Iter[(Symbol, Value)] {
  m
  .to_array()
  .map(kv => {
    let (k, v) = kv
    let s = Symbol::of(k)
    (s, Primitive(Normal(name=s, v)))
  })
  .iter()
}

///|
fn fold_args_d(
  args : FixedArray[Value],
  i : Int,
  init : Double,
  fdd : (Double, Double) -> Double,
) -> Value raise SchemeException {
  let mut accd = init
  for i in i..<args.length() {
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

///|
fn fold_args_i(
  args : FixedArray[Value],
  i : Int,
  init : Int,
  fii : (Int, Int) -> Int,
  fdd : (Double, Double) -> Double,
) -> Value raise SchemeException {
  let mut acci = init
  for i in i..<args.length() {
    match args[i] {
      Int(x) => acci = fii(acci, x)
      Double(x) =>
        return fold_args_d(args, i + 1, fdd(acci.to_double(), x), fdd)
      _ => raise TypeError(i)
    }
  }
  Int(acci)
}

///|
/// `number?`
/// 
/// `+`, `-`, `*`, `/`
/// 
/// `=`, `>`, `<`
pub let number_primitive : Iter[(Symbol, Value)] = prim_iter_from_map({
  "number?": args => match args {
    [Int(_) | Double(_)] => True
    [_] => False
    _ => raise ArgumentCount
  },
  "=": args => match args {
    [Int(a), Int(b)] => Value::bool(a == b)
    [Double(a), Double(b)] => Value::bool(a == b)
    [Double(a), Int(b)] => Value::bool(a == b.to_double())
    [Int(a), Double(b)] => Value::bool(a.to_double() == b)
    [Int(_) | Double(_), _] => raise TypeError(1)
    [_, _] => raise TypeError(0)
    _ => raise ArgumentCount
  },
  ">": args => match args {
    [Int(a), Int(b)] => Value::bool(a > b)
    [Double(a), Double(b)] => Value::bool(a > b)
    [Double(a), Int(b)] => Value::bool(a > b.to_double())
    [Int(a), Double(b)] => Value::bool(a.to_double() > b)
    [Int(_) | Double(_), _] => raise TypeError(1)
    [_, _] => raise TypeError(0)
    _ => raise ArgumentCount
  },
  "<": args => match args {
    [Int(a), Int(b)] => Value::bool(a < b)
    [Double(a), Double(b)] => Value::bool(a < b)
    [Double(a), Int(b)] => Value::bool(a < b.to_double())
    [Int(a), Double(b)] => Value::bool(a.to_double() < b)
    [Int(_) | Double(_), _] => raise TypeError(1)
    [_, _] => raise TypeError(0)
    _ => raise ArgumentCount
  },
  "+": fold_args_i(_, 0, 0, Int::add, Double::add),
  "-": args => match args {
    [] => raise ArgumentCount
    [Int(arg0)] => Int(Int::neg(arg0))
    [Double(arg0)] => Double(Double::neg(arg0))
    [Int(arg0), ..] => fold_args_i(args, 1, arg0, Int::sub, Double::sub)
    [Double(arg0), ..] => fold_args_d(args, 1, arg0, Double::sub)
    _ => raise TypeError(0)
  },
  "*": fold_args_i(_, 0, 1, Int::mul, Double::mul),
  "/": args => match args {
    [] => raise ArgumentCount
    [Int(arg0)] => Int(Int::div(1, arg0))
    [Double(arg0)] => Double(Double::div(1, arg0))
    [Int(arg0), ..] => fold_args_i(args, 1, arg0, Int::div, Double::div)
    [Double(arg0), ..] => fold_args_d(args, 1, arg0, Double::div)
    _ => raise TypeError(0)
  },
})

///|
/// `cons`, `car`, `cdr`
/// 
/// `null?`, `pair?`
pub let pair_primitive : Iter[(Symbol, Value)] = prim_iter_from_map({
  "car": args => match args {
    [Pair(l, _)] => l
    [_] => raise TypeError(0)
    _ => raise ArgumentCount
  },
  "cdr": args => match args {
    [Pair(_, r)] => r
    [_] => raise TypeError(0)
    _ => raise ArgumentCount
  },
  "null?": args => match args {
    [Nil] => True
    [_] => False
    _ => raise ArgumentCount
  },
  "pair?": args => match args {
    [Pair(_)] => True
    [_] => False
    _ => raise ArgumentCount
  },
  "cons": args => match args {
    [l, r] => Pair(l, r)
    _ => raise ArgumentCount
  },
  "list": Value::list(_),
})

///|
/// `string?`, `string-append`, `string->symbol`
/// 
/// `symbol->string`, `number->string`, `value->string`
pub let string_primitive : Iter[(Symbol, Value)] = prim_iter_from_map({
  "string?": args => match args {
    [String(_)] => True
    [_] => False
    _ => raise ArgumentCount
  },
  "string->symbol": args => match args {
    [String(s)] => Value::symbol(s)
    [_] => raise TypeError(0)
    _ => raise ArgumentCount
  },
  "symbol->string": args => match args {
    [Symbol(x)] => String(x.to_string())
    [_] => raise TypeError(0)
    _ => raise ArgumentCount
  },
  "number->string": args => match args {
    [Int(x)] => String(x.to_string())
    [Double(x)] => String(x.to_string())
    [_] => raise TypeError(0)
    _ => raise ArgumentCount
  },
  "value->string": args => match args {
    [v] => String(v.to_string())
    _ => raise ArgumentCount
  },
  "string-append": args => {
    let b = StringBuilder::new()
    for i, v in args {
      guard v is String(str) else { raise TypeError(i) }
      b.write_string(str)
    }
    String(b.to_string())
  },
})

///|
/// `vector`, `vector?`, `make-vector`, `vector-length`
/// 
/// `vector-ref`, `vector-set!`
pub let vector_primitive : Iter[(Symbol, Value)] = prim_iter_from_map({
  "vector?": args => match args {
    [Vector(_)] => True
    [_] => False
    _ => raise ArgumentCount
  },
  "vector-length": args => match args {
    [Vector(v)] => Int(v.length())
    [_] => raise TypeError(0)
    _ => raise ArgumentCount
  },
  "vector-ref": args => match args {
    [Vector(v), Int(i)] => {
      guard 0 <= i && i < v.length() else { raise InvalidArgument(1) }
      v.unsafe_get(i)
    }
    [Vector(_), _] => raise InvalidArgument(1)
    [_, _] => raise TypeError(0)
    _ => raise ArgumentCount
  },
  "vector-set!": args => match args {
    [Vector(v), Int(i), x] => {
      guard 0 <= i && i < v.length() else { raise InvalidArgument(1) }
      v[i] = x
      Value::default()
    }
    [Vector(_), _, _] => raise InvalidArgument(1)
    [_, _, _] => raise TypeError(0)
    _ => raise ArgumentCount
  },
  "vector": Vector(_),
  "make-vector": args => match args {
    [n] => {
      guard n is Int(n) else { raise TypeError(0) }
      guard n >= 0 else { raise InvalidArgument(0) }
      Vector(FixedArray::make(n, Int(0)))
    }
    [n, init] => {
      guard n is Int(n) else { raise TypeError(0) }
      guard n >= 0 else { raise InvalidArgument(0) }
      Vector(FixedArray::make(n, init))
    }
    _ => raise ArgumentCount
  },
})

///|
/// `eq?`, `symbol?`, `call/cc`, `apply`
pub let other_primitive : Iter[(Symbol, Value)] = prim_iter_from_map({
    "symbol?": args => match args {
      [Symbol(_)] => True
      [_] => False
      _ => raise ArgumentCount
    },
    "procedure?": args => match args {
      [Primitive(_) | Closure(_) | Continuation(_)] => True
      [_] => False
      _ => raise ArgumentCount
    },
    "eq?": args => match args {
      [a, b] => Value::bool(a.eq(b))
      _ => raise ArgumentCount
    },
  }) +
  [CallCC, Apply].iter().map(x => (x.name(), Primitive(x)))

///|
pub let all_base_primitive : Iter[(Symbol, Value)] = number_primitive +
  pair_primitive +
  string_primitive +
  vector_primitive +
  other_primitive
