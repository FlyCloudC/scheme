///|
pub impl Show for Environment with output(self, logger) {
  logger.write_string("+frame")
  match self.closure {
    Some({ name: Some(name), .. }) => logger.write_string("(\{name})")
    None => logger.write_string("(global)")
    _ => ()
  }
  logger.write_string(":\n")
  for k, v in self.binds {
    logger
    ..write_string("| ")
    ..write_object(k)
    ..write_string(" : ")
    ..write_object(v)
    .write_char('\n')
  }
  match self.next {
    None => logger.write_string("+--------")
    Some(x) => logger.write_object(x)
  }
}

///|
pub fn lookup(self : Environment, name : Symbol) -> Value raise SchemeException {
  match self.binds.get(name) {
    Some(x) => x
    None => self.next.or_error(UndefineVar).lookup(name)
  }
}

///|
pub fn set_var(
  self : Environment,
  name : Symbol,
  new_value : Value,
) -> Unit raise SchemeException {
  match self.binds.get(name) {
    Some(_) => self.binds[name] = new_value
    None => self.next.or_error(UndefineVar).set_var(name, new_value)
  }
}

///|
pub fn define_var(self : Environment, name : Symbol, new_value : Value) -> Unit {
  self.binds[name] = new_value
}

///|
pub fn define_vars(
  self : Environment,
  name_value : Iter[(Symbol, Value)],
) -> Unit {
  for nv in name_value {
    self.binds[nv.0] = nv.1
  }
}

///|
pub fn extend(
  self : Environment,
  names : FixedArray[Symbol],
  values : FixedArray[Value],
  closure : Closure,
) -> Environment {
  let binds = @hashmap.new(capacity=names.length())
  values.eachi(fn(i, v) { binds[names[i]] = v })
  { binds, next: Some(self), closure: Some(closure) }
}

///|
pub fn Environment::base() -> Environment {
  { next: None, binds: @hashmap.new(), closure: None }
}
