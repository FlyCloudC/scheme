///|
let env : Environment = {
  let env = Environment::base()
  env.define_vars(all_base_primitive)
  env
}

///|
#callsite(autofill(args_loc, loc))
pub fn run(
  code : String,
  content? : String = "",
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Unit raise {
  let exps = parse(code)
  let b = StringBuilder::new()
  let vm = VM::new(env~)
  let mut first = true
  for exp in exps {
    vm.next = exp.to_core_form().compile()
    vm.run_to_halt()
    if vm.acc != Value::default() {
      if first {
        first = false
      } else {
        b.write_char('\n')
      }
      b.write_object(vm.acc)
    }
  }
  inspect(b, content~, loc~, args_loc~)
}

///|
test "fact" {
  run("(+ 1 (* 2 3))", content="7")
  (
    #|(define (fact x)
    #|   (if (= x 0)
    #|       1 ; base case
    #|       (* x (fact (- x 1))))) ; rec case
  )
  |> run
  run("(fact 5)", content="120")
}

///|
test "OOP" {
  (
    #|(define (make-account money)
    #|  (define (take x)
    #|    (set! money (- money x)))
    #|  (lambda (msg)
    #|    (if (eq? msg 'take) take
    #|        (if (eq? msg 'look) money
    #|            ('error)))))
    #|(define a (make-account 100))
    #|(define b (make-account 1000))
  )
  |> run
  run(" (b 'look)", content="1000")
  run(" (a 'look)", content="100")
  run(" ((a 'take) 20)")
  run(" (a 'look)", content="80")
  run(" (b 'look)", content="1000")
  run(" ((b 'take) 30)")
  run(" (a 'look)", content="80")
  run(" (b 'look)", content="970")
}

///|
test "sort" {
  (
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
    #|
    #|(define ls1 '(3 5 2 4 1))
  )
  |> run
  run("ls1", content="(3 5 2 4 1)")
  run("(sort ls1)", content="(5 4 3 2 1)")
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
  while !(vm.next is Apply) {
    vm.run_one_step()
  }
  let before = stack_length()
  vm.run_one_step()
  let after = stack_length()
  assert_eq(before, after)
}

///|
test "call/cc 1" {
  run("(define *k* #f)")
  run("(cons 1 (call/cc (lambda (k) (set! *k* k) 2)))", content="(1 . 2)")
  run("*k*", content="#<continuation>")
  run("(*k* 3)", content="(1 . 3)")
}

///|
test "call/cc 2" {
  (
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
  )
  |> run
  run("(find 'b '(a b c))", content="#t")
  run("(find 'd '(a b c))", content="#f")
}

///|
test "apply" {
  run("(apply vector '(1 2 3 4 5))", content="#(1 2 3 4 5)")
}

///|
test "expand" {
  run("(let ((x 1) (y 2)) (+ x y))", content="3")
  run("(and)", content="#t")
  run("(and #f)", content="#f")
  run("(and (> 1 0) (> 2 0))", content="#t")
  run("(or)", content="#f")
  run("(or 1)", content="1")
  run("(or 1 2)", content="1")
  run("(or #f 2)", content="2")
  run("(let ((x (and 1 2)) (y (and 3 4))) (and x y))", content="4")
  (
    #|(define (fact x)
    #|   (cond 
    #|     ((= x 0) 1)
    #|     (else (* x (fact (- x 1))))))
  )
  |> run
  run("(fact 2)", content="2")
}
