///|
pub impl Eq for Primitive with op_equal(self, other) {
  physical_equal(self, other)
}

///|
pub impl Show for Primitive with output(self, logger) {
  logger..write_string("#<procedure ")..write_object(self.name).write_char('>')
}

///|
pub impl Eq for Closure with op_equal(self, other) {
  physical_equal(self, other)
}

///|
pub impl Show for Closure with output(self, logger) {
  match self.name {
    None => logger.write_string("#<procedure>")
    Some(name) =>
      logger..write_string("#<procedure ")..write_object(name).write_char('>')
  }
}

// +---------------------------+
// |           Value           |
// +---------------------------+
///|
pub impl Default for Value with default() { Symbol("done") }

///|
pub fn eq(self : Value, other : Value) -> Bool {
  match (self, other) {
    (Nil, Nil) | (True, True) | (False, False) => true
    (Pair(_) | Vector(_) | Primitive(_) | Closure(_), _) =>
      physical_equal(self, other)
    (Int(a), Int(b)) => a == b
    (Double(a), Double(b)) => a == b
    (Symbol(a), Symbol(b)) => a == b
    _ => false
  }
}

///|
pub impl Show for Value with output(self, logger) {
  match self {
    Nil => logger.write_string("()")
    Pair(l, r) => {
      logger..write_char('(').write_object(l)
      loop r {
        Nil => logger.write_char(')')
        Pair(l, r) => {
          logger..write_char(' ').write_object(l)
          continue r
        }
        v => logger..write_string(" . ")..write_object(v).write_char(')')
      }
    }
    Int(i) => logger.write_object(i)
    Double(d) => logger.write_object(d)
    True => logger.write_string("#t")
    False => logger.write_string("#f")
    Symbol(s) => logger.write_object(s)
    String(s) => logger.write_object(s)
    Primitive(prim) => logger.write_object(prim)
    Closure(closure) => logger.write_object(closure)
    Vector(a) => logger.write_iter(a.iter(), prefix="#(", sep=" ", suffix=")")
  }
}

///|
pub fn Value::bool(b : Bool) -> Value {
  match b {
    true => True
    false => False
  }
}

///|
pub fn list_tail_and_length(self : Value) -> (Value, Int) {
  loop self, 0 {
    Pair(_, r), len => continue r, len + 1
    tail, len => (tail, len)
  }
}
