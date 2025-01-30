///|
pub type Symbol String derive(Hash)

///|
let symbol_table : @hashmap.T[String, Symbol] = @hashmap.new(capacity=100)

///|
pub fn Symbol::new(str : String) -> Symbol {
  symbol_table.get_or_init(str, fn() { Symbol(str) })
}

///|
pub impl Eq for Symbol with op_equal(a, b) { physical_equal(a, b) }

///|
pub impl Show for Symbol with output(self, logger) {
  logger.write_string(self._)
}

///|
let default_symbol : Symbol = Symbol::new("void")

///|
pub impl Default for Symbol with default() { default_symbol }
