///|
fn run_and_print(code : String, env : Environment) -> String! {
  let exps = parse!(code)
  let b = StringBuilder::new()
  for exp in exps {
    let ei = exp.to_core_from!().compile()
    try {
      let vm = VM::new(inst=ei, env~)
      vm.run_to_halt!()
      let v = vm.acc
      if v != Value::default() {
        b..write_object(v).write_char('\n')
      }
    } catch {
      e => b..write_object(e).write_char('\n')
    }
  }
  b.to_string()
}

test "fact" {
  let env0 = Environment::base()..add_number_primitive()
  let program =
    #|(+ 1 (* 2 3))
    #|(define (fact x)
    #|   (if (= x 0)
    #|       1 ; base case
    #|       (* x (fact (- x 1))))) ; rec case
    #|(fact 5)
  program
  |> run_and_print!(env0)
  |> inspect!(
    content=
      #|7
      #|120
      #|
    ,
  )
}

test "OOP" {
  let env0 = Environment::base()..add_number_primitive()..add_base_primitive()
  let program_0 =
    #|(define (make-account money)
    #|  (define (take x)
    #|    (set! money (- money x)))
    #|  (lambda (msg)
    #|    (if (eq? msg 'take) take
    #|        (if (eq? msg 'look) money
    #|            ('error)))))
    #|(define a (make-account 100))
    #|(define b (make-account 1000))
  program_0 |> run_and_print!(env0) |> inspect!(content="")
  let program_1 =
    #|(a 'look)
    #|(b 'look)
    #|((a 'take) 20)
    #|(a 'look)
    #|(b 'look)
    #|((b 'take) 30)
    #|(a 'look)
    #|(b 'look)
  program_1
  |> run_and_print!(env0)
  |> inspect!(
    content=
      #|100
      #|1000
      #|80
      #|1000
      #|80
      #|970
      #|
    ,
  )
}

test "example in README" {
  let env = Environment::base()..add_number_primitive()
  let code =
    #|(define (fact x)
    #|   (if (= x 0)
    #|       1                      ; base case
    #|       (* x (fact (- x 1))))) ; rec case
    #|(fact 5)
  let sexp = parse!(code)
  let program = [ //
    sexp[0].to_core_from!(),
    sexp[1].to_core_from!(),
  ]
  let inst = program.map(compile)
  // make VM, load "(define (fact x) ...)" and env
  let vm = VM::new(inst=inst[0], env~)
  // run, add "fact" to env
  vm.run_to_halt!()
  inspect!( //
    vm.env.lookup!(Symbol::of("fact")),
    content="#<procedure fact>",
  )
  // load and run "(fact 5)"
  vm.next = inst[1]
  vm.run_to_halt!()
  inspect!(vm.acc, content="120")
}
