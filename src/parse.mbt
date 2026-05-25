///|
pub fn parse(code : StringView) -> Array[Value] raise ParseException {
  letrec parse_value = fn(rest : ArrayView[Token]) raise ParseException {
    guard rest is [t, .. rest] else { raise UnexpectedEndOfInput }
    match t {
      ST => (True, rest)
      SF => (False, rest)
      Lp => parse_list(rest)
      SLp => parse_vector(rest)
      Quote => {
        let (v, rest) = parse_value(rest)
        (Pair(Value::symbol("quote"), Pair(v, Nil)), rest)
      }
      Int(i) => (Int(i), rest)
      Double(d) => (Double(d), rest)
      Symbol(s) => (Value::symbol(s), rest)
      String(s) => (String(s), rest)
      Dot | Rp => raise UnexpectedToken(t)
    }
  }
  and parse_list = fn(rest) raise ParseException {
    let res = []
    for rest = rest {
      match rest {
        [Rp, .. rest] => break (to_sexp(res), rest)
        [Dot, .. rest] => {
          let (tail, rest) = parse_value(rest)
          match rest {
            [] => raise UnexpectedEndOfInput
            [Rp, .. rest] =>
              break (res.rev_fold(init=tail, (acc, x) => Pair(x, acc)), rest)
            [t, ..] => raise MoreThanOneAfterDot(t)
          }
        }
        rest => {
          let (v, rest) = parse_value(rest)
          res.push(v)
          continue rest
        }
      }
    }
  }
  and parse_vector = fn(rest) raise ParseException {
    let res = []
    for rest = rest {
      match rest {
        [Rp, .. rest] => break (Vector(FixedArray::from_array(res)), rest)
        rest => {
          let (v, rest) = parse_value(rest)
          res.push(v)
          continue rest
        }
      }
    }
  }

  let tokens = @tokenizer.read(code).map(x => x.0) catch {
    e => raise ReadException(e)
  }
  let res = []
  for tokens = tokens[:]; tokens is [_, ..]; {
    let (v, rest) = parse_value(tokens)
    res.push(v)
    continue rest
  }
  res
}

///|
test "parse then to_string = identify" {
  let a =
    #|(define (fact x)
    #|  (if (= x 0)
    #|      1 ; base case
    #|      (* x (fact (- x 1)))))
  let sa = parse(a)[0]
  inspect(sa, content="(define (fact x) (if (= x 0) 1 (* x (fact (- x 1)))))")
  let a1 = sa.to_string()
  let sa1 = parse(a1)[0]
  assert_eq(sa, sa1)
}

///|
test "parse list" {
  debug_inspect(try? parse("(1)"), content=(
    #|Ok([<Value: (1)>])
  ))
  debug_inspect(try? parse("(2)("), content="Err(UnexpectedEndOfInput)")
  debug_inspect(try? parse("(3 (4 5)"), content="Err(UnexpectedEndOfInput)")
  debug_inspect(try? parse("(3 (4 5))"), content=(
    #|Ok([<Value: (3 (4 5))>])
  ))
  debug_inspect(try? parse("(3 (4 5)))"), content="Err(UnexpectedToken(Rp))")
}

///|
test "parse dot list" {
  debug_inspect(
    try? parse("(1 2 . 3 4)"),
    content="Err(MoreThanOneAfterDot(Int(4)))",
  )
  debug_inspect(try? parse("(1 2 .)"), content="Err(UnexpectedToken(Rp))")
  debug_inspect(try? parse("(1 2 . )"), content="Err(UnexpectedToken(Rp))")
  debug_inspect(parse("(1 2 . 3)"), content=(
    #|[<Value: (1 2 . 3)>]
  ))
  debug_inspect(parse("(1 2 .3)"), content=(
    #|[<Value: (1 2 . 3)>]
  ))
}

///|
test "parse quote" {
  debug_inspect(try? parse("'"), content="Err(UnexpectedEndOfInput)")
  debug_inspect(parse("'a"), content=(
    #|[<Value: (quote a)>]
  ))
  debug_inspect(parse("'()"), content=(
    #|[<Value: (quote ())>]
  ))
  debug_inspect(parse("''a"), content=(
    #|[<Value: (quote (quote a))>]
  ))
  debug_inspect(parse("'(a 2)"), content=(
    #|[<Value: (quote (a 2))>]
  ))
  debug_inspect(parse("''(a 2)"), content=(
    #|[<Value: (quote (quote (a 2)))>]
  ))
  debug_inspect(parse("f'a"), content=(
    #|[<Value: f>, <Value: (quote a)>]
  ))
  debug_inspect(parse("f'a'b"), content=(
    #|[<Value: f>, <Value: (quote a)>, <Value: (quote b)>]
  ))
}
