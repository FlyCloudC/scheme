///|
pub type! ReadException {
  UnterminatedString(String, Int)
  InvalidStringEscaping(String, Char, Int)
  InvalidAfterSharp(Char?, Int)
} derive(Show)

///|
pub(all) enum Token {
  Lp // (
  Rp // )
  SLp // #(
  Quote // '
  Dot // .
  ST // #t
  SF // #f
  Int(Int)
  Double(Double)
  Symbol(String)
  String(String)
} derive(Show, Eq)

///|
priv struct Tokenizer {
  code : String
  res : Array[(Token, Int, Int)]
  mut i : Int
} derive(Show)
