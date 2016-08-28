(library (mattie interpreter)
         (export make-interpreter)
         (import (rnrs)
                 (mattie util)
                 (mattie parser)
                 (mattie parser combinators))

  (define (make-interpreter src entry-point)
    (let ((r (parse-language src)))
      (assert r)
      (assert (string=? (car r) ""))
      (validate-defs (cdr r) entry-point)
      (make-lang (cdr r) entry-point)))

  (define arities `((lcat . 2) (rcat . 2) (alt . 2) (and . 2) (map . 2)
                    (rep . 1) (opt . 1) (neg . 1)
                    (atom . 0) (lterm . 0) (rterm . 0) (dot . 0) (state . 0)))

  (define (get-syms d)
    (if (eq? (car d) 'atom) (list (cdr d))
      (case (cdr (assq (car d) arities))
        ((0) '())
        ((1) (get-syms (cdr d)))
        ((2) (append (get-syms (cadr d)) (get-syms (cddr d)))))))

  (define (validate-defs ds entry-point)
    (let ((rules (map cdadr ds)))
      (assert (member entry-point rules))
      (let* ((ss (map (λ (d) (get-syms (cddr d))) ds))
             (rs (fold-left append '() ss))
             (undefined-rules (filter (λ (s) (not (member s rules))) rs)))
        (assert (null? undefined-rules)))))

  (define (unescape-term t)
    (if (eq? #\' (string-ref t 0))
      (substring t 1 (string-length t))
      (list->string
        (let loop ((cs (string->list (substring t 1 (- (string-length t) 1)))))
          (cond ((null? cs) cs)
                ((char=? (car cs) #\\)
                 (assert (not (null? (cdr cs)))) ;; grammar should prevent this
                 (loop (cons (cadr cs) (cddr cs))))
                (else (cons (car cs) (loop (cdr cs)))))))))

  (define static-handlers ;; everything except atoms, which are handled
    `((lcat . ,conc)      ;; according to the production rule they name
      (rcat . ,(λ (a b) (λ x (string-append (apply a x) (apply b x)))))
      (alt . ,disj)
      (and . ,conj)
      (map . ,(λ (a f) (lmap f a)))
      (lterm . ,(λ (t) (term (unescape-term t))))
      (rterm . ,(λ (t) (const (unescape-term t))))
      (opt . ,opt)
      (neg . ,comp)
      (dot . ,(const lang-1))
      (state . ,(const (λ (_ st) st)))
      (rep . ,(λ (l) (if (eq? l lang-1) lang-t (rep l))))))

  (define (linguify b hs)
    (apply (cdr (assq (car b) hs))
           (case (cdr (assq (car b) arities))
             ((0) (list (cdr b)))
             ((1) (list (linguify (cdr b) hs)))
             ((2) (list (linguify (cadr b) hs) (linguify (cddr b) hs))))))

  (define (make-lang defs entry-point)
    (define (dispatch a)
      (define-lazy f (cdr (assq (string->symbol a) rule-table))) f)

    (define handlers (cons (cons 'atom dispatch) static-handlers))

    (define (add-entry t d)
      (cons (cons (string->symbol (cdadr d))(linguify (cddr d) handlers)) t))

    (define rule-table (fold-left add-entry '() defs))

    (cdr (assq (string->symbol entry-point) rule-table))))
