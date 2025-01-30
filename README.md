# FlyCloudC/scheme

A Scheme interpreter implemented in Moonbit. It will be used for teaching purposes and not too many optimizations will be added. The understandability of the code is given top priority.

Reference Book: [Structure and Interpretation of Computer Programs](https://mitp-content-server.mit.edu/books/content/sectbyfn/books_pres_0/6515/sicp.zip/full-text/book/book.html)

## example

```moonbit
fn main {
  let env = Env::base()..add_number_prim()
  let code =
    #|(define (fact x)
    #|   (if (= x 0)
    #|       1                      ; base case
    #|       (* x (fact (- x 1))))) ; rec case
    #|(fact 5)
  let sexp = parse!(code)
  let program = [CoreForm::from_sexp!(sexp[0]), CoreForm::from_sexp!(sexp[1])]
  let inst = program.map(analyze)
  run_async(fn() {
    try {
      inst[0]!!(env) |> ignore
      inst[1]!!(env) |> println // output: 120
    } catch {
      _ => panic()
    }
  })
}
```
