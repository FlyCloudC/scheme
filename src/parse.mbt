///|
pub fn parse(code : String) -> Array[Value]!ParseException {
  let tokens = try {
    @tokenizer.read!(code)
  } catch {
    _ => raise UnexpectedEndOfInput
  }
  let mut i = 0
  fn next() -> _!ParseException {
    i += 1
    if i < tokens.length() {
      tokens[i]
    } else {
      raise UnexpectedEndOfInput
    }
  }

  fn parse_value(token : Token) -> _!ParseException {
    match token {
      ST => True
      SF => False
      Lp => parse_list!()
      SLp => parse_vector!()
      Quote => Pair(Value::symbol("quote"), Pair(parse_value!(next!()), Nil))
      Int(i) => Int(i)
      Double(d) => Double(d)
      Symbol(s) => Value::symbol(s)
      String(s) => String(s)
      Dot | Rp => raise UnexpectedToken(token)
    }
  }

  fn parse_list() -> _!ParseException {
    let res = []
    loop next!() {
      Rp => res.to_sexp()
      Dot =>
        match next!() {
          Rp => raise MisTokenAfterDot
          t => {
            let r = parse_value!(t)
            match next!() {
              Rp => res.rev_fold(init=r, fn { acc, x => Pair(x, acc) })
              t => raise MoreThanOneAfterDot(t)
            }
          }
        }
      t => {
        res.push(parse_value!(t))
        continue next!()
      }
    }
  }

  fn parse_vector() -> _!ParseException {
    let res = []
    loop next!() {
      Rp => FixedArray::makei(res.length(), fn(i) { res[i] }) |> Vector
      t => {
        res.push(parse_value!(t))
        continue next!()
      }
    }
  }

  let res = []
  while i < tokens.length() {
    res.push(parse_value!(tokens[i]))
    i += 1
  }
  res
}

test "fact" {
  let a =
    #|(define (fact x)
    #|  (if (= x 0)
    #|      1 ; base case
    #|      (* x (fact (- x 1)))))
  let sa = parse!(a)[0]
  inspect!(sa, content="(define (fact x) (if (= x 0) 1 (* x (fact (- x 1)))))")
  let a1 = sa.to_string()
  let sa1 = parse!(a1)[0]
  assert_eq!(sa, sa1)
}

test "dot" {
  inspect!(parse?("(1 2 . 3 4)"), content="Err(MoreThanOneAfterDot(Int(4)))")
  inspect!(parse?("(1 2 .)"), content="Err(MisTokenAfterDot)")
  inspect!(parse?("(1 2 . )"), content="Err(MisTokenAfterDot)")
  inspect!(parse!("(1 2 . 3)"), content="[(1 2 . 3)]")
  inspect!(parse!("(1 2 .3)"), content="[(1 2 . 3)]")
}
