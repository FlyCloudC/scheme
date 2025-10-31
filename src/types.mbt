///|
using @symbol {type Symbol}

///|
pub(all) suberror SchemeException {
  UndefineVar
  CallNonProcedure
  ArgumentCount
  TypeError(Int)
  InvalidArgument(Int)
  DevideZero
} derive(Show)

///|
pub struct Closure {
  env : Environment
  parm_names : FixedArray[Symbol]
  body : Inst
  name : Symbol?
}

///|
pub(all) enum Primitive {
  Normal(name~ : Symbol, (FixedArray[Value]) -> Value raise SchemeException)
  CallCC
  Apply
}

///|
pub(all) enum Value {
  Nil
  True
  False
  Pair(Value, Value)
  Int(Int)
  Double(Double)
  Symbol(Symbol)
  String(String)
  Vector(FixedArray[Value])
  Primitive(Primitive)
  Closure(Closure)
  Continuation(Frame?)
}

///|
pub(all) struct Environment {
  binds : @hashmap.HashMap[Symbol, Value]
  next : Environment?
  closure : Closure?
}

///|
pub enum CoreForm {
  SelfEval(Value)
  Var(Symbol)
  Quote(Value)
  Lambda(FixedArray[Symbol], CoreForm)
  Begin(FixedArray[CoreForm], CoreForm)
  If(CoreForm, CoreForm, CoreForm?)
  Apply(CoreForm, FixedArray[CoreForm])
  Set(Symbol, CoreForm)
  Define(Symbol, CoreForm)
} derive(Show)

// -----------------------------
// |            VM             |
// -----------------------------

///|
pub enum Inst {
  Const(Value, Inst)
  Refer(Symbol, Inst)
  Return
  Close(FixedArray[Symbol], Inst, Symbol?, Inst)
  Branch(Inst, Inst)
  Save(Inst, Inst)
  Args(Int, Inst)
  Push(Int, Inst)
  Apply
  Set(Symbol, Inst)
  Define(Symbol, Inst)
}

///|
pub(all) struct VM {
  mut acc : Value
  mut next : Inst
  mut env : Environment
  mut rib : FixedArray[Value]
  mut stack : Frame?
}

///|
pub struct Frame {
  ret : Inst
  env : Environment
  rib : FixedArray[Value]
  stack : Frame?
}

// -----------------------------
// |          Parse            |
// -----------------------------

///|
using @tokenizer {type Token}

///|
pub suberror ParseException {
  UnexpectedToken(Token)
  MoreThanOneAfterDot(Token)
  UnexpectedEndOfInput
  ReadException(@tokenizer.ReadException)
} derive(Show)
