///|
pub suberror ReadException {
  UnterminatedString(StringView)
  InvalidStringEscaping(StringView)
  InvalidAfterSharp(StringView)
} derive(Show)

///|
pub(all) enum Token {
  /// (
  Lp
  /// )
  Rp
  /// #(
  SLp
  /// '
  Quote
  /// .
  Dot
  /// #t
  ST
  /// #f
  SF
  Int(Int)
  Double(Double)
  Symbol(String)
  String(String)
} derive(Show, Eq)
