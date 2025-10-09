///|
pub fn Primitive::name(self : Primitive) -> Symbol {
  match self {
    Normal(_, name~) => name
    CallCC => Symbol::of("call/cc")
    Apply => Symbol::of("apply")
  }
}

///|
pub impl Show for Primitive with output(self, logger) {
  logger
  ..write_string("#<procedure ")
  ..write_object(self.name())
  ..write_char('>')
}

///|
pub impl Show for Closure with output(self, logger) {
  match self.name {
    None => logger.write_string("#<procedure>")
    Some(name) =>
      logger..write_string("#<procedure ")..write_object(name)..write_char('>')
  }
}

// +---------------------------+
// |           Value           |
// +---------------------------+

///|
pub impl Default for Value with default() {
  Value::symbol("done")
}

///|
pub fn Value::eq(self : Value, other : Value) -> Bool {
  match (self, other) {
    (Nil | True | False | Pair(_) | Int(_) | Double(_) | String(_), _) =>
      physical_equal(self, other)
    (Symbol(a), Symbol(b)) => Symbol::equal(a, b)
    (Vector(a), Vector(b)) => physical_equal(a, b)
    (Primitive(a), Primitive(b)) => physical_equal(a, b)
    (Closure(a), Closure(b)) => physical_equal(a, b)
    _ => false
  }
}

///|
pub impl Eq for Value with equal(self, other) {
  match (self, other) {
    (Nil, Nil) | (True, True) | (False, False) => true
    (Int(a), Int(b)) => Int::equal(a, b)
    (Double(a), Double(b)) => Double::equal(a, b)
    (Symbol(a), Symbol(b)) => Symbol::equal(a, b)
    (String(a), String(b)) => String::equal(a, b)
    (Primitive(a), Primitive(b)) => physical_equal(a, b)
    (Closure(a), Closure(b)) => physical_equal(a, b)
    (Pair(_), Pair(_)) | (Vector(_), Vector(_)) => recur_equal(self, other)
    _ => false
  }
}

///|
fn recur_equal(a : Value, b : Value) -> Bool {
  // Todo: According to R7RS, equal must terminate
  match (a, b) {
    (Pair(la, ra), Pair(lb, rb)) => Value::equal(la, lb) && Value::equal(ra, rb)
    (Vector(a), Vector(b)) => FixedArray::equal(a, b)
    _ => panic()
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
        v => logger..write_string(" . ")..write_object(v)..write_char(')')
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
    Continuation(_) => logger.write_string("#<continuation>")
    Vector(a) => logger.write_iter(a.iter(), prefix="#(", sep=" ", suffix=")")
  }
}

///|
pub fn Value::symbol(s : String) -> Value {
  Value::Symbol(Symbol::of(s))
}

///|
pub fn Value::bool(b : Bool) -> Value {
  match b {
    true => True
    false => False
  }
}

///|
pub fn Value::list(vs : FixedArray[Value]) -> Value {
  vs.rev_fold(init=Nil, (acc, x) => Pair(x, acc))
}

///|
pub fn list_tail_and_length(self : Value) -> (Value, Int) {
  loop (self, 0) {
    (Pair(_, r), len) => continue (r, len + 1)
    (tail, len) => (tail, len)
  }
}

///|
pub fn unsafe_to_fixedarray(self : Value, length : Int) -> FixedArray[Value] {
  let res = FixedArray::make(length, Value::default())
  loop (0, self) {
    (i, Pair(l, r)) => {
      res[i] = l
      continue (i + 1, r)
    }
    _ => res
  }
}
