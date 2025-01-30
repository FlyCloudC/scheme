///|
typealias Symbol = @symbol.Symbol

///|
pub(all) type! SchemeException {
  InvalidArgument(FixedArray[Value])
  UndefineVar(Symbol)
  CallNonProcedure(Value)
  ArgumentCount(Symbol?)
  TypeError(Symbol?)
  DevideZero
} derive(Show)

///|
pub struct Closure {
  env : Environment
  parm_names : FixedArray[Symbol]
  body : async (Environment) -> Value!SchemeException
  name : Symbol?
}

///|
pub(all) struct Primitive {
  body : (FixedArray[Value]) -> Value!SchemeException
  name : Symbol
}

///|
pub(all) enum Value {
  Nil
  Pair(Value, Value)
  Int(Int)
  Double(Double)
  True
  False
  Symbol(Symbol)
  String(String)
  Primitive(Primitive)
  Closure(Closure)
  Vector(FixedArray[Value])
} derive(Eq)

///|
pub(all) struct Environment {
  binds : @hashmap.T[Symbol, Value]
  next : Environment?
  closure : Closure?
}

///|
pub enum CoreForm {
  SelfEval(Value)
  Var(Symbol)
  Quote(Value)
  Lambda(FixedArray[Symbol], CoreForm, name~ : Symbol?)
  Begin(FixedArray[CoreForm], CoreForm)
  If(CoreForm, CoreForm, CoreForm?)
  Apply(CoreForm, FixedArray[CoreForm])
  Set(Symbol, CoreForm)
  Define(Symbol, CoreForm)
} derive(Show)

// -----------------------------
// |          Parse            |
// -----------------------------

///|
typealias Token = @tokenizer.Token

///|
pub type! ParseException {
  UnexpectedToken(Token)
  MoreThanOneAfterDot(Token)
  MisTokenAfterDot
  UnexpectedEndOfInput
} derive(Show)
