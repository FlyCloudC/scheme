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
pub fn read(code : String) -> Array[Token]!ReadException {
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
        let next_token = self.read_next_token!(c)
        self.res.push(next_token)
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
        co => raise UnFinishSharp(co)
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
  let b = StringBuilder::new()
  loop self.peek_next() {
    Some('"') => String(b.to_string())
    Some(c) => {
      b.write_char(c)
      continue self.peek_next()
    }
    None => raise UnFinishString(b.to_string())
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

test "fact" {
  let a =
    #|(define (fact x)
    #|  (if (= x 0)
    #|      1 ; base case
    #|      (* x (fact (- x 1)))))
  assert_eq!(read!(a), [
    Lp,
    Symbol("define"),
    Lp,
    Symbol("fact"),
    Symbol("x"),
    Rp,
    Lp,
    Symbol("if"),
    Lp,
    Symbol("="),
    Symbol("x"),
    Int(0),
    Rp,
    Int(1),
    Lp,
    Symbol("*"),
    Symbol("x"),
    Lp,
    Symbol("fact"),
    Lp,
    Symbol("-"),
    Symbol("x"),
    Int(1),
    Rp,
    Rp,
    Rp,
    Rp,
    Rp,
  ])
}

test "special" {
  let a =
    #|'a
    #|'(1 2 3)
    #|#(a)
  assert_eq!(read!(a), [
    Quote,
    Symbol("a"),
    Quote,
    Lp,
    Int(1),
    Int(2),
    Int(3),
    Rp,
    SLp,
    Symbol("a"),
    Rp,
  ])
}
