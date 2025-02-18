///|
type Symbol Int derive(Hash)

///|
let map_str_to_sym : @hashmap.T[String, Symbol] = @hashmap.new(capacity=100)

///|
let map_sym_id_to_str : Array[String] = []

///|
let get_next_id : () -> Int = {
  let mut i = -1
  fn() {
    i += 1
    i
  }
}

///|
pub fn Symbol::of(str : String) -> Symbol {
  map_str_to_sym.get_or_init(str, fn() {
    let res = Symbol(get_next_id())
    map_sym_id_to_str.push(str)
    res
  })
}

///|
pub impl Eq for Symbol with op_equal(a, b) {
  a._ == b._
}

///|
pub impl Show for Symbol with output(self, logger) {
  logger.write_string(map_sym_id_to_str[self._])
}

///|
pub impl Show for Symbol with to_string(self) {
  map_sym_id_to_str[self._]
}

///|
let default_symbol : Symbol = Symbol::of("default-symbol")

///|
pub impl Default for Symbol with default() {
  default_symbol
}

///|
test "symbol string" {
  let s = "a中a🐇a"
  assert_eq!(Symbol::of(s).to_string(), s)
}

///|
test "symbol eq" {
  let a1 = Symbol::of("a")
  let bbbbb1 = Symbol::of("bbbbb")
  let a2 = Symbol::of("a")
  let bbbbb2 = Symbol::of("bbbbb")
  // eq
  assert_true!(a1 == a2)
  assert_true!(bbbbb1 == bbbbb2)
  // // not eq
  assert_true!(a1 != bbbbb1)
  assert_true!(a1 != bbbbb2)
  assert_true!(a2 != bbbbb1)
  assert_true!(a2 != bbbbb2)
}
