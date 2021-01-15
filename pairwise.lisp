(in-package #:ctype)

;;;; Pair methods
;;;; That is, methods on two specific ctype classes.

;;; cclass ctypes are excluded from several other ctypes (when things are
;;; normalized correctly), so we can mark their conjunctions as empty, etc.

(defmacro defexclusive/2 (class1 class2)
  `(progn
     (defmethod subctypep ((ct1 ,class1) (ct2 ,class2)) (values nil t))
     (defmethod subctypep ((ct1 ,class2) (ct2 ,class1)) (values nil t))
     (defmethod disjointp ((ct1 ,class1) (ct2 ,class2)) (values t t))
     (defmethod disjointp ((ct1 ,class2) (ct2 ,class1)) (values t t))
     (defmethod conjoin/2 ((ct1 ,class1) (ct2 ,class2)) (bot))
     (defmethod conjoin/2 ((ct1 ,class2) (ct2 ,class1)) (bot))
     (defmethod subtract ((ct1 ,class1) (ct2 ,class2)) ct1)
     (defmethod subtract ((ct2 ,class2) (ct1 ,class1)) ct2)))

(defmacro defexclusive (&rest classes)
  `(progn
     ,@(loop for (class1 . rest) on classes
             nconc (loop for class2 in rest
                         collect `(defexclusive/2 ,class1 ,class2)))))

(defexclusive ccons range ccomplex carray cfunction)
(defexclusive/2 cclass range)
(defexclusive/2 cclass ccomplex)
(defexclusive/2 cclass carray)

;;; Some cclass ctype relations we unfortunately have to handle specially.
(defun sequence-cclass-p (cclass)
  (eq (class-name (cclass-class cclass)) 'sequence))
(defmethod subctypep ((ct1 ccons) (ct2 cclass))
  (values (sequence-cclass-p ct2) t))
(defmethod subctypep ((ct1 cclass) (ct2 ccons)) (values nil t))
(defmethod disjointp ((ct1 ccons) (ct2 cclass))
  (values (not (sequence-cclass-p ct2)) t))
(defmethod disjointp ((ct1 cclass) (ct2 ccons))
  (values (not (sequence-cclass-p ct1)) t))
(defmethod conjoin/2 ((ct1 cclass) (ct2 ccons))
  (if (sequence-cclass-p ct1) ct2 (bot)))
(defmethod conjoin/2 ((ct1 ccons) (ct2 cclass))
  (if (sequence-cclass-p ct2) ct1 (bot)))
(defmethod subtract ((ct1 ccons) (ct2 cclass))
  (if (sequence-cclass-p ct2) (bot) ct1))
(defmethod subtract ((ct1 cclass) (ct2 ccons))
  (if (sequence-cclass-p ct1) (call-next-method) (bot)))
;;; NULL is (MEMBER NIL), and cmember methods should already handle things.

(defun subfunction-cclass-p (cclass)
  ;; FIXME: We skip the env here, is that okay?
  (subclassp (cclass-class cclass) (find-class 'function t)))
(defmethod subctypep ((ct1 cfunction) (ct2 cclass))
  ;; FUNCTION itself is never a cclass, so
  (values nil t))
(defmethod subctypep ((ct1 cclass) (ct2 cfunction))
  (if (subfunction-cclass-p ct1)
      (if (top-function-p ct2) (values t t) (values nil nil))
      (values nil t)))
(defmethod conjoin/2 ((ct1 cclass) (ct2 cfunction))
  (if (subfunction-cclass-p ct1)
      (if (top-function-p ct2) ct1 (call-next-method))
      (bot)))
(defmethod conjoin/2 ((ct1 cfunction) (ct2 cclass))
  (if (subfunction-cclass-p ct2)
      (if (top-function-p ct1) ct2 (call-next-method))
      (bot)))
(defmethod subtract ((ct1 cclass) (ct2 cfunction))
  (if (subfunction-cclass-p ct1)
      (if (top-function-p ct2) (bot) (call-next-method))
      ct1))
(defmethod subtract ((ct1 cfunction) (ct2 cclass))
  (if (subfunction-cclass-p ct2)
      (call-next-method)
      ct1))

;;; Some ctypes represent an infinite number of possible objects, so they are
;;; never subctypes of any member ctype.

(defmacro definfinite (class)
  `(defmethod subctypep ((ct1 ,class) (ct2 cmember)) (values nil t)))

(definfinite cclass)
(definfinite ccons)
(definfinite range)
(definfinite ccomplex)
(definfinite carray)
(definfinite cfunction)