///|
pub fn parse(code : String) -> Array[Value] raise ParseException {
  let tokens = @tokenizer.read(code).map(x => match x {
    (token, _, _) => token
  }) catch {
    e => raise ReadException(e)
  }
  let mut current_pos = 0
  let next = fn() raise ParseException {
    current_pos += 1
    if current_pos < tokens.length() {
      tokens[current_pos]
    } else {
      raise UnexpectedEndOfInput
    }
  }
  letrec parse_value = fn(token : Token) raise ParseException {
    match token {
      ST => True
      SF => False
      Lp => parse_list()
      SLp => parse_vector()
      Quote => Pair(Value::symbol("quote"), Pair(parse_value(next()), Nil))
      Int(i) => Int(i)
      Double(d) => Double(d)
      Symbol(s) => Value::symbol(s)
      String(s) => String(s)
      Dot | Rp => raise UnexpectedToken(token)
    }
  }
  and parse_list = fn() raise ParseException {
    let res = []
    loop next() {
      Rp => to_sexp(res)
      Dot =>
        match next() {
          Rp => raise MisTokenAfterDot
          t => {
            let r = parse_value(t)
            match next() {
              Rp => res.rev_fold(init=r, (acc, x) => Pair(x, acc))
              t => raise MoreThanOneAfterDot(t)
            }
          }
        }
      t => {
        res.push(parse_value(t))
        continue next()
      }
    }
  }
  and parse_vector = fn() raise ParseException {
    let res = []
    loop next() {
      Rp => FixedArray::makei(res.length(), fn(i) { res[i] }) |> Vector
      t => {
        res.push(parse_value(t))
        continue next()
      }
    }
  }

  let res = []
  while current_pos < tokens.length() {
    res.push(parse_value(tokens[current_pos]))
    current_pos += 1
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
  inspect(try? parse("(1 2 .)"), content="Err(MisTokenAfterDot)")
  inspect(try? parse("(1 2 . )"), content="Err(MisTokenAfterDot)")
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
