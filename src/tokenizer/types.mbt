///|
pub type! ReadException {
  UnFinishString(String)
  StringEscaping(String, Char)
  UnFinishSharp(Char?)
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
  res : Array[Token]
  mut i : Int
} derive(Show)
