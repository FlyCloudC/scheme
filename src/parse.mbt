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
    loop rest {
      [Rp, .. rest] => (to_sexp(res), rest)
      [Dot, .. rest] => {
        let (tail, rest) = parse_value(rest)
        match rest {
          [] => raise UnexpectedEndOfInput
          [Rp, .. rest] =>
            (res.rev_fold(init=tail, (acc, x) => Pair(x, acc)), rest)
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
  and parse_vector = fn(rest) raise ParseException {
    let res = []
    loop rest {
      [Rp, .. rest] => (Vector(FixedArray::from_array(res)), rest)
      rest => {
        let (v, rest) = parse_value(rest)
        res.push(v)
        continue rest
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
  inspect(try? parse("(1)"), content="Ok([(1)])")
  inspect(try? parse("(2)("), content="Err(UnexpectedEndOfInput)")
  inspect(try? parse("(3 (4 5)"), content="Err(UnexpectedEndOfInput)")
  inspect(try? parse("(3 (4 5))"), content="Ok([(3 (4 5))])")
  inspect(try? parse("(3 (4 5)))"), content="Err(UnexpectedToken(Rp))")
}

///|
test "parse dot list" {
  inspect(try? parse("(1 2 . 3 4)"), content="Err(MoreThanOneAfterDot(Int(4)))")
  inspect(try? parse("(1 2 .)"), content="Err(UnexpectedToken(Rp))")
  inspect(try? parse("(1 2 . )"), content="Err(UnexpectedToken(Rp))")
  inspect(parse("(1 2 . 3)"), content="[(1 2 . 3)]")
  inspect(parse("(1 2 .3)"), content="[(1 2 . 3)]")
}

///|
test "parse quote" {
  inspect(try? parse("'"), content="Err(UnexpectedEndOfInput)")
  inspect(parse("'a"), content="[(quote a)]")
  inspect(parse("'()"), content="[(quote ())]")
  inspect(parse("''a"), content="[(quote (quote a))]")
  inspect(parse("'(a 2)"), content="[(quote (a 2))]")
  inspect(parse("''(a 2)"), content="[(quote (quote (a 2)))]")
  inspect(parse("f'a"), content="[f, (quote a)]")
  inspect(parse("f'a'b"), content="[f, (quote a), (quote b)]")
}
