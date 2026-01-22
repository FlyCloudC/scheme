///|
fn normal(
  name : String,
  func : (FixedArray[Value]) -> Value raise SchemeException,
) -> (Symbol, Value) {
  let name = Symbol::of(name)
  (name, Primitive(Normal(name~, func)))
}

///|
fn special(p : Primitive) -> (Symbol, Value) {
  (p.name(), Primitive(p))
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
pub let number_primitive : ReadOnlyArray[(Symbol, Value)] = [
  normal("number?", args => match args {
    [Int(_) | Double(_)] => True
    [_] => False
    _ => raise ArgumentCount
  }),
  normal("=", args => match args {
    [Int(a), Int(b)] => Value::bool(a == b)
    [Double(a), Double(b)] => Value::bool(a == b)
    [Double(a), Int(b)] => Value::bool(a == b.to_double())
    [Int(a), Double(b)] => Value::bool(a.to_double() == b)
    [Int(_) | Double(_), _] => raise TypeError(1)
    [_, _] => raise TypeError(0)
    _ => raise ArgumentCount
  }),
  normal(">", args => match args {
    [Int(a), Int(b)] => Value::bool(a > b)
    [Double(a), Double(b)] => Value::bool(a > b)
    [Double(a), Int(b)] => Value::bool(a > b.to_double())
    [Int(a), Double(b)] => Value::bool(a.to_double() > b)
    [Int(_) | Double(_), _] => raise TypeError(1)
    [_, _] => raise TypeError(0)
    _ => raise ArgumentCount
  }),
  normal("<", args => match args {
    [Int(a), Int(b)] => Value::bool(a < b)
    [Double(a), Double(b)] => Value::bool(a < b)
    [Double(a), Int(b)] => Value::bool(a < b.to_double())
    [Int(a), Double(b)] => Value::bool(a.to_double() < b)
    [Int(_) | Double(_), _] => raise TypeError(1)
    [_, _] => raise TypeError(0)
    _ => raise ArgumentCount
  }),
  normal("+", fold_args_i(_, 0, 0, Int::add, Double::add)),
  normal("-", args => match args {
    [] => raise ArgumentCount
    [Int(arg0)] => Int(Int::neg(arg0))
    [Double(arg0)] => Double(Double::neg(arg0))
    [Int(arg0), ..] => fold_args_i(args, 1, arg0, Int::sub, Double::sub)
    [Double(arg0), ..] => fold_args_d(args, 1, arg0, Double::sub)
    _ => raise TypeError(0)
  }),
  normal("*", fold_args_i(_, 0, 1, Int::mul, Double::mul)),
  normal("/", args => match args {
    [] => raise ArgumentCount
    [Int(arg0)] => Int(Int::div(1, arg0))
    [Double(arg0)] => Double(Double::div(1, arg0))
    [Int(arg0), ..] => fold_args_i(args, 1, arg0, Int::div, Double::div)
    [Double(arg0), ..] => fold_args_d(args, 1, arg0, Double::div)
    _ => raise TypeError(0)
  }),
]

///|
/// `cons`, `car`, `cdr`
/// 
/// `null?`, `pair?`
pub let pair_primitive : ReadOnlyArray[(Symbol, Value)] = [
  normal("car", args => match args {
    [Pair(l, _)] => l
    [_] => raise TypeError(0)
    _ => raise ArgumentCount
  }),
  normal("cdr", args => match args {
    [Pair(_, r)] => r
    [_] => raise TypeError(0)
    _ => raise ArgumentCount
  }),
  normal("null?", args => match args {
    [Nil] => True
    [_] => False
    _ => raise ArgumentCount
  }),
  normal("pair?", args => match args {
    [Pair(_)] => True
    [_] => False
    _ => raise ArgumentCount
  }),
  normal("cons", args => match args {
    [l, r] => Pair(l, r)
    _ => raise ArgumentCount
  }),
  normal("list", Value::list(_)),
]

///|
/// `string?`, `string-append`, `string->symbol`
/// 
/// `symbol->string`, `number->string`, `value->string`
pub let string_primitive : ReadOnlyArray[(Symbol, Value)] = [
  normal("string?", args => match args {
    [String(_)] => True
    [_] => False
    _ => raise ArgumentCount
  }),
  normal("string->symbol", args => match args {
    [String(s)] => Value::symbol(s)
    [_] => raise TypeError(0)
    _ => raise ArgumentCount
  }),
  normal("symbol->string", args => match args {
    [Symbol(x)] => String(x.to_string())
    [_] => raise TypeError(0)
    _ => raise ArgumentCount
  }),
  normal("number->string", args => match args {
    [Int(x)] => String(x.to_string())
    [Double(x)] => String(x.to_string())
    [_] => raise TypeError(0)
    _ => raise ArgumentCount
  }),
  normal("value->string", args => match args {
    [v] => String(v.to_string())
    _ => raise ArgumentCount
  }),
  normal("string-append", args => {
    let b = StringBuilder::new()
    for i, v in args {
      guard v is String(str) else { raise TypeError(i) }
      b.write_string(str)
    }
    String(b.to_string())
  }),
]

///|
/// `vector`, `vector?`, `make-vector`, `vector-length`
/// 
/// `vector-ref`, `vector-set!`
pub let vector_primitive : ReadOnlyArray[(Symbol, Value)] = [
  normal("vector?", args => match args {
    [Vector(_)] => True
    [_] => False
    _ => raise ArgumentCount
  }),
  normal("vector-length", args => match args {
    [Vector(v)] => Int(v.length())
    [_] => raise TypeError(0)
    _ => raise ArgumentCount
  }),
  normal("vector-ref", args => match args {
    [Vector(v), Int(i)] => {
      guard 0 <= i && i < v.length() else { raise InvalidArgument(1) }
      v.unsafe_get(i)
    }
    [Vector(_), _] => raise InvalidArgument(1)
    [_, _] => raise TypeError(0)
    _ => raise ArgumentCount
  }),
  normal("vector-set!", args => match args {
    [Vector(v), Int(i), x] => {
      guard 0 <= i && i < v.length() else { raise InvalidArgument(1) }
      v[i] = x
      Value::default()
    }
    [Vector(_), _, _] => raise InvalidArgument(1)
    [_, _, _] => raise TypeError(0)
    _ => raise ArgumentCount
  }),
  normal("vector", Vector(_)),
  normal("make-vector", args => match args {
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
  }),
]

///|
/// `eq?`, `procedure?`, `symbol?`
/// 
/// `call/cc`, `apply`
pub let other_primitive : ReadOnlyArray[(Symbol, Value)] = [
  normal("symbol?", args => match args {
    [Symbol(_)] => True
    [_] => False
    _ => raise ArgumentCount
  }),
  normal("procedure?", args => match args {
    [Primitive(_) | Closure(_) | Continuation(_)] => True
    [_] => False
    _ => raise ArgumentCount
  }),
  normal("eq?", args => match args {
    [a, b] => Value::bool(a.eq(b))
    _ => raise ArgumentCount
  }),
  special(CallCC),
  special(Apply),
]

///|
pub let all_base_primitive : ReadOnlyArray[(Symbol, Value)] = [
    ..number_primitive, ..pair_primitive, ..string_primitive, ..vector_primitive,
    ..other_primitive,
  ]
  |> ReadOnlyArray::from_iter
