///|
pub(open) trait ToSexp {
  to_sexp(Self) -> Value
}

///|
pub(all) type! FromSexpError Value derive(Show)

///|
pub(open) trait FromSexp {
  from_sexp(Value) -> Self!FromSexpError
}

///|
pub impl ToSexp for Value with to_sexp(self) {
  self
}

///|
pub impl ToSexp for Int with to_sexp(self) {
  Int(self)
}

///|
pub impl ToSexp for Double with to_sexp(self) {
  Double(self)
}

///|
pub impl ToSexp for Bool with to_sexp(self) {
  Value::bool(self)
}

///|
pub impl ToSexp for Symbol with to_sexp(self) {
  Symbol(self)
}

///|
pub impl ToSexp for String with to_sexp(self) {
  String(self)
}

///|
pub impl[A : ToSexp] ToSexp for Array[A] with to_sexp(self) {
  self.rev_fold(init=Nil, fn { acc, x => Pair(x.to_sexp(), acc) })
}

///|
pub impl[A : ToSexp] ToSexp for FixedArray[A] with to_sexp(self) {
  self.rev_fold(init=Nil, fn { acc, x => Pair(x.to_sexp(), acc) })
}

///|
pub impl[A : ToSexp, B : ToSexp] ToSexp for (A, B) with to_sexp(self) {
  Pair(self.0.to_sexp(), self.1.to_sexp())
}

///|
pub impl[A : ToSexp, B : ToSexp] ToSexp for Iter2[A, B] with to_sexp(self) {
  self.to_array().to_sexp()
}

///|
pub impl ToSexp for Json with to_sexp(self) {
  match self {
    Null => Nil
    True => True
    False => False
    Number(x) => Int(x.to_int())
    String(x) => Value::symbol(x)
    Array(xs) => xs.to_sexp()
    Object({ "type": "inproper list", "ls": Array(xs), "r": r, .. }) =>
      xs.rev_fold(init=r.to_sexp(), fn { acc, x => Pair(x.to_sexp(), acc) })
    Object({ "type": "string", "value": String(s), .. }) => String(s)
    Object({ "type": "double", "value": Number(d), .. }) => Double(d)
    Object({ "type": "vector", "value": Array(arr), .. }) =>
      FixedArray::makei(arr.length(), fn(i) { arr[i].to_sexp() }) |> Vector
    Object(m) => Pair(Value::symbol("object"), Pair(m.iter2().to_sexp(), Nil))
  }
}

///|
pub impl FromSexp for Json with from_sexp(self) {
  match self {
    Nil => []
    True => True
    False => False
    Int(x) => Number(x.to_double())
    Symbol(s) => String(s.to_string())
    Pair(l, r) => {
      let res = [Json::from_sexp!(l)]
      loop r {
        Nil => Array(res)
        Pair(l, r) => {
          res.push(Json::from_sexp!(l))
          continue r
        }
        r =>
          {
            "type": "inproper list",
            "ls": Array(res),
            "r": Json::from_sexp!(r),
          }
      }
    }
    Double(d) => { "type": "double", "value": Number(d) }
    String(s) => { "type": "string", "value": String(s) }
    Vector(arr) => {
      let res = []
      for v in arr {
        res.push(Json::from_sexp!(v))
      }
      { "type": "vector", "value": Array(res) }
    }
    Closure(_) | Primitive(_) | Continuation(_) => raise FromSexpError(self)
  }
}

///|
test "json" {
  let j0 : Json = [
    "define",
    ["fact", "x"],
    ["if", ["=", "x", 0], 1, ["*", "x", ["fact", ["-", "x", 1]]]],
  ]
  assert_eq!(j0, j0.to_sexp() |> Json::from_sexp!())
  let s0 : Value = Vector([
    Double(1),
    Int(2),
    String("str"),
    Value::symbol("sym"),
    Pair(Pair(Value::symbol("a1"), Value::symbol("a2")), Value::symbol("b")),
    Pair(Int(1), Pair(Int(2), Nil)),
  ])
  assert_eq!(s0, (s0 |> Json::from_sexp!()).to_sexp())
  @json.inspect!(Json::from_sexp!(s0), content={
    "type": "vector",
    "value": [
      { "type": "double", "value": 1 },
      2,
      { "type": "string", "value": "str" },
      "sym",
      {
        "type": "inproper list",
        "ls": [{ "type": "inproper list", "ls": ["a1"], "r": "a2" }],
        "r": "b",
      },
      [1, 2],
    ],
  })
}
