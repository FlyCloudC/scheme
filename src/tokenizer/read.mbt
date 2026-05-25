///|
pub fn read(code : StringView) -> Array[(Token, Int, Int)] raise ReadException {
  let tokens = []
  for c_rest = code; c_rest is [c, .. rest]; {
    match c {
      ' ' | '\n' | '\r' | '\t' => continue rest
      ';' => continue read_comment(rest)
      _ => {
        let (t, rest) = read_next_token(c, rest)
        tokens.push((t, c_rest.start_offset(), rest.start_offset()))
        continue rest
      }
    }
  }
  tokens
}

///|
fn read_next_token(
  c : Char,
  rest : StringView,
) -> (Token, StringView) raise ReadException {
  match c {
    // 特殊 Token
    '(' => (Lp, rest)
    ')' => (Rp, rest)
    '\'' => (Quote, rest)
    '.' => (Dot, rest)
    '#' =>
      match rest {
        ['(', .. rest] => (SLp, rest)
        ['t', .. rest] => (ST, rest)
        ['f', .. rest] => (SF, rest)
        _ => raise InvalidAfterSharp(rest)
      }
    '0'..='9' as c => read_number(c, rest)
    '"' => read_string(rest)
    _ => read_symbol(c, rest)
  }
}

///|
fn read_number(c : Char, rest : StringView) -> (Token, StringView) {
  for rest = rest, acc = c.to_int() - '0' {
    match rest {
      ['0'..='9' as c, .. rest] => continue rest, acc * 10 + (c.to_int() - '0')
      ['.', .. rest] => break read_double(acc, rest)
      _ => break (Int(acc), rest)
    }
  }
}

///|
fn read_double(acc : Int, rest : StringView) -> (Token, StringView) {
  for rest = rest, acc = acc.to_double(), i = 0.1 {
    match rest {
      ['0'..='9' as c, .. rest] =>
        continue rest, acc + i * (c.to_int() - '0').to_double(), i / 10
      _ => break (Double(acc), rest)
    }
  }
}

///|
fn read_comment(rest : StringView) -> StringView {
  for rest = rest {
    match rest {
      [] => break []
      ['\n', .. rest] => break rest
      [_, .. rest] => continue rest
    }
  }
}

///|
fn read_string(rest : StringView) -> (Token, StringView) raise ReadException {
  let b = StringBuilder::new()
  for rest = rest {
    match rest {
      ['\\', .. rest] =>
        match rest {
          ['\\' | '"' as c, .. rest] => {
            b.write_char(c)
            continue rest
          }
          [_, ..] => raise InvalidStringEscaping(rest)
          [] => raise UnterminatedString(rest)
        }
      ['"', .. rest] => break (String(b.to_string()), rest)
      [c, .. rest] => {
        b.write_char(c)
        continue rest
      }
      [] as rest => raise UnterminatedString(rest)
    }
  }
}

///|
fn read_symbol(c : Char, rest : StringView) -> (Token, StringView) {
  let b = StringBuilder::new()
  b.write_char(c)
  for rest = rest {
    match rest {
      [] | [' ' | '\n' | '\r' | '\t' | '(' | ')' | '\'' | '#', ..] as rest =>
        break (Symbol(b.to_string()), rest)
      [c, .. rest] => {
        b.write_char(c)
        continue rest
      }
    }
  }
}

///|
test "fact" {
  (
    #|(define (fact x)
    #|  (if (= x 0)
    #|      1 ; base case
    #|      (* x (fact (- x 1)))))
  )
  |> read()
  |> @debug.assert_eq([
    (Lp, 0, 1),
    (Symbol("define"), 1, 7),
    (Lp, 8, 9),
    (Symbol("fact"), 9, 13),
    (Symbol("x"), 14, 15),
    (Rp, 15, 16),
    (Lp, 19, 20),
    (Symbol("if"), 20, 22),
    (Lp, 23, 24),
    (Symbol("="), 24, 25),
    (Symbol("x"), 26, 27),
    (Int(0), 28, 29),
    (Rp, 29, 30),
    (Int(1), 37, 38),
    (Lp, 57, 58),
    (Symbol("*"), 58, 59),
    (Symbol("x"), 60, 61),
    (Lp, 62, 63),
    (Symbol("fact"), 63, 67),
    (Lp, 68, 69),
    (Symbol("-"), 69, 70),
    (Symbol("x"), 71, 72),
    (Int(1), 73, 74),
    (Rp, 74, 75),
    (Rp, 75, 76),
    (Rp, 76, 77),
    (Rp, 77, 78),
    (Rp, 78, 79),
  ])
}

///|
test "special" {
  (
    #|'a
    #|'(1 2 3)
    #|#(a)
    #|("ada" 1.2 "wadwa\";;'")
  )
  |> read()
  |> @debug.assert_eq([
    (Quote, 0, 1),
    (Symbol("a"), 1, 2),
    (Quote, 3, 4),
    (Lp, 4, 5),
    (Int(1), 5, 6),
    (Int(2), 7, 8),
    (Int(3), 9, 10),
    (Rp, 10, 11),
    (SLp, 12, 14),
    (Symbol("a"), 14, 15),
    (Rp, 15, 16),
    (Lp, 17, 18),
    (String("ada"), 18, 23),
    (Double(1.2), 24, 27),
    (String("wadwa\";;'"), 28, 40),
    (Rp, 40, 41),
  ])
}

///|
test "unicode" {
  (
    #|(中 "🐇")
  )
  |> read()
  |> @debug.assert_eq([
    (Lp, 0, 1),
    (Symbol("中"), 1, 2),
    (String("🐇"), 3, 7),
    (Rp, 7, 8),
  ])
}
