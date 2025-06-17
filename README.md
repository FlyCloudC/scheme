# FlyCloudC/scheme

A Scheme interpreter implemented in Moonbit. It will be used for teaching purposes and not too many optimizations will be added. The understandability of the code is given top priority.

Reference: 

- [Three Implementation Models for Scheme](https://legacy.cs.indiana.edu/~dyb/papers/3imp.pdf) Chapter 3 The Heap-Based Model

- [Structure and Interpretation of Computer Programs](https://mitp-content-server.mit.edu/books/content/sectbyfn/books_pres_0/6515/sicp.zip/full-text/book/book.html)

## example

```moonbit
test "example in README" {
  let env = Environment::base()
  env.add_number_primitive()
  let code =
    #|(define (fact x)
    #|   (if (= x 0)
    #|       1                      ; base case
    #|       (* x (fact (- x 1))))) ; rec case
    #|(fact 5)
  let sexp = parse(code)
  let program = sexp.map(Value::to_core_form)
  let inst = program.map(compile)
  // make VM, load "(define (fact x) ...)" and env
  let vm = VM::new(inst=inst[0], env~)
  // run, add "fact" to env
  vm.run_to_halt()
  inspect( //
    vm.env.lookup(Symbol::of("fact")),
    content="#<procedure fact>",
  )
  // load and run "(fact 5)"
  vm.next = inst[1]
  vm.run_to_halt()
  inspect(vm.acc, content="120")
}
```
