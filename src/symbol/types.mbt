///|
struct Symbol(Int) derive(Eq)

///|
let map_str_to_sym : @hashmap.HashMap[String, Symbol] = @hashmap.new(
  capacity=100,
)

///|
let map_sym_id_to_str : Array[String] = []

///|
pub fn Symbol::of(str : String) -> Symbol {
  map_str_to_sym.get_or_init(str, () => {
    let id = map_sym_id_to_str.length()
    map_sym_id_to_str.push(str)
    Symbol(id)
  })
}

///|
let gen_counter : Ref[Int] = { val: 0 }

///|
pub fn Symbol::generate() -> Symbol {
  gen_counter.val -= 1
  Symbol(gen_counter.val)
}

///|
pub fn Symbol::is_generated(self : Symbol) -> Bool {
  self.0 < 0
}

///|
pub impl Show for Symbol with output(self, logger) {
  if self.is_generated() {
    logger..write_string("#{gensym ")..write_object(-self.0).write_char('}')
  } else {
    logger.write_string(map_sym_id_to_str[self.0])
  }
}

///|
pub impl Show for Symbol with to_string(self) {
  if self.is_generated() {
    "#{gensym \{-self.0}}"
  } else {
    map_sym_id_to_str[self.0]
  }
}

///|
let default_symbol : Symbol = Symbol::of("default-symbol")

///|
pub impl Default for Symbol with default() {
  default_symbol
}

///|
pub impl Hash for Symbol with hash_combine(self, hasher) {
  hasher.combine_int(self.0)
}

///|
pub impl Hash for Symbol with hash(self) {
  self.0
}

///|
test "symbol string" {
  let s = "a中a🐇a"
  assert_eq(Symbol::of(s).to_string(), s)
}

///|
test "symbol eq" {
  let a1 = Symbol::of("a")
  let bbbbb1 = Symbol::of("bbbbb")
  let a2 = Symbol::of("a")
  let bbbbb2 = Symbol::of("bbbbb")
  // eq
  assert_true(a1 == a2)
  assert_true(bbbbb1 == bbbbb2)
  // // not eq
  assert_true(a1 != bbbbb1)
  assert_true(a1 != bbbbb2)
  assert_true(a2 != bbbbb1)
  assert_true(a2 != bbbbb2)
}

///|
test "symbol generate" {
  let a0 = Symbol::of("a0")
  let a1 = Symbol::generate()
  let a2 = Symbol::generate()
  assert_eq(a1, a1)
  assert_eq(a2, a2)
  assert_not_eq(a0, a1)
  assert_not_eq(a0, a2)
  assert_not_eq(a1, a2)
}
