///|
fn is_space(c : Char) -> Bool {
  match c {
    ' ' | '\n' | '\r' | '\t' => true
    _ => false
  }
}

///|
fn is_symbol_end(c : Char) -> Bool {
  match c {
    '(' | ')' | '#' | '\'' => true
    _ => is_space(c)
  }
}

///|
fn length(self : Tokenizer) -> Int {
  self.code.codepoint_length()
}

///|
fn op_get(self : Tokenizer, idx : Int) -> Char {
  self.code.codepoint_at(idx)
}

///|
fn next(self : Tokenizer) -> Unit {
  self.i += 1
}

///|
fn peek(self : Tokenizer) -> Char? {
  if self.i < self.length() {
    Some(self[self.i])
  } else {
    None
  }
}

///|
fn peek_next(self : Tokenizer) -> Char? {
  if self.i + 1 < self.length() {
    Some(self[self.i + 1])
  } else {
    None
  }
}

///|
pub fn read(code : String) -> Array[(Token, Int, Int)]!ReadException {
  let self : Tokenizer = { i: 0, code, res: Array::new() }
  loop self.peek() {
    None => {
      guard self.i >= self.length()
      self.res
    }
    Some(c) => {
      self.next()
      if c == ';' {
        self.read_comment()
      } else if not(is_space(c)) {
        let begin = self.i - 1
        let next_token = self.read_next_token!(c)
        let end = self.i
        self.res.push((next_token, begin, end))
      }
      continue self.peek()
    }
  }
}

///|
fn read_next_token(self : Tokenizer, c : Char) -> Token!ReadException {
  match c {
    // 特殊 Token
    '(' => Lp
    ')' => Rp
    '\'' => Quote
    '.' => Dot
    '#' => {
      let c = match self.peek() {
        Some('(') => SLp
        Some('t') => ST
        Some('f') => SF
        co => raise InvalidAfterSharp(co, self.i - 1)
      }
      self.next()
      c
    }
    '0'..='9' as c => self.read_number(c)
    '"' => self.read_string!()
    _ => self.read_symbol(c)
  }
}

///|
fn read_number(self : Tokenizer, c : Char) -> Token {
  // Todo: Int out of range
  loop self.peek(), c - '0' {
    Some('0'..='9' as c), acc =>
      continue self..next().peek(), acc * 10 + (c - '0')
    Some('.'), acc => self..next().read_double(acc)
    _, acc => Int(acc)
  }
}

///|
fn read_double(self : Tokenizer, z : Int) -> Token {
  loop self.peek(), z.to_double(), 0.1 {
    Some('0'..='9' as c), acc, i =>
      continue self..next().peek(), acc + i * (c - '0').to_double(), i / 10
    _, acc, _ => Double(acc)
  }
}

///|
fn read_comment(self : Tokenizer) -> Unit {
  loop self.peek() {
    None => ()
    Some('\n') => self.next()
    Some(_) => continue self..next().peek()
  }
}

///|
fn read_string(self : Tokenizer) -> Token!ReadException {
  let begin = self.i - 1
  let b = StringBuilder::new()
  loop self.peek() {
    Some('\\') =>
      match self..next().peek() {
        Some('"' | '\\' as c) => {
          b.write_char(c)
          continue self..next().peek()
        }
        Some(c) => raise InvalidStringEscaping(b.to_string(), c, self.i)
        None => raise UnterminatedString(b.to_string(), begin)
      }
    Some('"') => {
      self.next()
      String(b.to_string())
    }
    Some(c) => {
      b.write_char(c)
      continue self..next().peek()
    }
    None => raise UnterminatedString(b.to_string(), begin)
  }
}

///|
fn read_symbol(self : Tokenizer, c : Char) -> Token {
  let b = StringBuilder::new()..write_char(c)
  loop self.peek() {
    Some(c) =>
      if not(is_symbol_end(c)) {
        b.write_char(c)
        continue self..next().peek()
      }
    None => ()
  }
  Symbol(b.to_string())
}

///|
test "fact" {
  #|(define (fact x)
  #|  (if (= x 0)
  #|      1 ; base case
  #|      (* x (fact (- x 1)))))
  |> read!()
  |> assert_eq!([
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
  #|'a
  #|'(1 2 3)
  #|#(a)
  #|("ada" 1.2 "wadwa\";;'")
  |> read!()
  |> assert_eq!([
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
  #|(中 "🐇")
  |> read!()
  |> assert_eq!([
    (Lp, 0, 1),
    (Symbol("中"), 1, 2),
    (String("🐇"), 3, 6),
    (Rp, 6, 7),
  ])
}
