(library (test runner)
         (export run-all-tests)
         (import (rnrs) (test util)
                 (test mattie parser stateful)
                 (test mattie interpreter)
                 (test mattie parser language))
  (define (run-all-tests)
    (run-test-suite "stateful parser tests" stateful-parser-tests)
    (run-test-suite "language parser tests" language-parser-tests)
    (run-test-suite "interpreter tests" interpreter-tests)
    ))
