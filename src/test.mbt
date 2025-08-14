///|
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

///|
fn run_and_to_string(code : String, env : Environment) -> String raise {
  let exps = parse(code)
  let b = StringBuilder::new()
  let vm = VM::new(env~)
  for exp in exps {
    vm.next = exp.to_core_form().compile()
    vm.run_to_halt()
    if vm.acc != Value::default() {
      b.write_object(vm.acc)
      b.write_char('\n')
    }
  }
  b.to_string()
}

///|
test "fact" {
  let env = Environment::base()
  env.add_number_primitive()
  let program =
    #|(+ 1 (* 2 3))
    #|(define (fact x)
    #|   (if (= x 0)
    #|       1 ; base case
    #|       (* x (fact (- x 1))))) ; rec case
    #|(fact 5)
  program
  |> run_and_to_string(env)
  |> inspect(
    content=(
      #|7
      #|120
      #|
    ),
  )
}

///|
test "OOP" {
  let env = Environment::base()
  env..add_number_primitive()..add_other_primitive()
  let code0 =
    #|(define (make-account money)
    #|  (define (take x)
    #|    (set! money (- money x)))
    #|  (lambda (msg)
    #|    (if (eq? msg 'take) take
    #|        (if (eq? msg 'look) money
    #|            ('error)))))
    #|(define a (make-account 100))
    #|(define b (make-account 1000))
  code0 |> run_and_to_string(env) |> inspect(content="")
  let code1 =
    #|(a 'look)
    #|(b 'look)
    #|((a 'take) 20)
    #|(a 'look)
    #|(b 'look)
    #|((b 'take) 30)
    #|(a 'look)
    #|(b 'look)
  code1
  |> run_and_to_string(env)
  |> inspect(
    content=(
      #|100
      #|1000
      #|80
      #|1000
      #|80
      #|970
      #|
    ),
  )
}

///|
test "sort" {
  let env = Environment::base()
  env..add_number_primitive()..add_pair_primitive()
  let code0 =
    #|(define (max2 a b)
    #|  (if (> a b) a b))
    #|
    #|(define (max ls)
    #|  (define (loop x ls)
    #|    (if (null? ls)
    #|        x
    #|        (loop (max2 x (car ls))
    #|              (cdr ls))))
    #|  (loop (car ls) (cdr ls)))
    #|
    #|(define (remove x ls)
    #|  (if (= x (car ls))
    #|      (cdr ls)
    #|      (cons (car ls)
    #|            (remove x (cdr ls)))))
    #|
    #|(define (sort ls)
    #|  (if (null? ls)
    #|      '()
    #|      (cons (max ls)
    #|            (sort (remove (max ls) ls)))))
  let code1 =
    #|(define ls1 '(3 5 2 4 1))
    #|ls1
    #|(sort ls1)
  run_and_to_string(code0, env) |> ignore
  run_and_to_string(code1, env)
  |> inspect(
    content=(
      #|(3 5 2 4 1)
      #|(5 4 3 2 1)
      #|
    ),
  )
}

///|
test "proper tail call" {
  let code =
    #|((lambda (f) (f f))
    #| (lambda (f) (f f)))
  let inst_def_f = parse(code)[0].to_core_form().compile()
  let vm = VM::new(inst=inst_def_f, env=Environment::base())
  let stack_length = () => loop (vm.stack, 0) {
    (Some(s), i) => continue (s.stack, i + 1)
    (None, i) => i
  }
  for {
    match vm.next {
      Apply => break
      _ => vm.run_one_step()
    }
  }
  let before = stack_length()
  vm.run_one_step()
  let after = stack_length()
  assert_eq(before, after)
}

///|
test "call/cc 1" {
  let env = Environment::base()
  env..add_other_primitive()..add_pair_primitive()
  let code =
    #|(define *k* #f)
    #|(cons 1 (call/cc (lambda (k) (set! *k* k) 2)))
    #|*k*
    #|(*k* 3)
    #|
  code
  |> run_and_to_string(env)
  |> inspect(
    content=(
      #|(1 . 2)
      #|#<continuation>
      #|(1 . 3)
      #|
    ),
  )
}

///|
test "call/cc 2" {
  let env = Environment::base()
  env..add_other_primitive()..add_pair_primitive()
  let code =
    #|(define (for-each ls f)
    #|  (if (pair? ls)
    #|      (begin (f (car ls))
    #|             (for-each (cdr ls) f))))
    #|
    #|(define (find x ls)
    #|  (call/cc (lambda (return)
    #|    (for-each ls (lambda (y)
    #|      (if (eq? x y) (return #t))))
    #|    #f)))
    #|
    #|(find 'b '(a b c))
    #|(find 'd '(a b c))
  code
  |> run_and_to_string(env)
  |> inspect(
    content=(
      #|#t
      #|#f
      #|
    ),
  )
}

///|
test "apply" {
  let env = Environment::base()
  env..add_other_primitive()..add_pair_primitive()..add_vector_primitive()
  let code =
    #|(apply vector '(1 2 3 4 5))
  code
  |> run_and_to_string(env)
  |> inspect(
    content=(
      #|#(1 2 3 4 5)
      #|
    ),
  )
}

///|
test "expand" {
  let env = Environment::base()
  env.add_number_primitive()
  let code =
    #|(let ((x 1)
    #|      (y 2))
    #|  (+ x y))
    #|
    #|(and)
    #|(and #f)
    #|(and (> 1 0) (> 2 0))
    #|
    #|(define (fact x)
    #|   (cond 
    #|     ((= x 0) 1)
    #|     (else (* x (fact (- x 1))))))
    #|(fact 2)
  code
  |> run_and_to_string(env)
  |> inspect(
    content=(
      #|3
      #|#t
      #|#f
      #|#t
      #|2
      #|
    ),
  )
}
