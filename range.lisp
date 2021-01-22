(in-package #:ctype)

(defmethod ctypep (object (ct range))
  (and (range-kindp object (range-kind ct))
       (let ((low (range-low ct)))
         (or (not low)
             (if (range-low-exclusive-p ct)
                 (< low object)
                 (<= low object))))
       (let ((high (range-high ct)))
         (or (not high)
             (if (range-high-exclusive-p ct)
                 (< object high)
                 (<= object high))))))

(defmethod subctypep ((ct1 range) (ct2 range))
  (values
   (and (eq (range-kind ct1) (range-kind ct2))
        (let ((low1 (range-low ct1)) (low2 (range-low ct2)))
          (or (not low2)
              (and low1
                   (or (< low2 low1)
                       (and (= low2 low1)
                            (or (range-low-exclusive-p ct1)
                                (not (range-low-exclusive-p ct2))))))))
        (let ((high1 (range-high ct1)) (high2 (range-high ct2)))
          (or (not high2)
              (and high1
                   (or (< high1 high2)
                       (and (= high1 high2)
                            (or (range-high-exclusive-p ct1)
                                (not (range-high-exclusive-p ct2)))))))))
   t))

(defmethod disjointp ((ct1 range) (ct2 range))
  (let ((rk1 (range-kind ct1)) (rk2 (range-kind ct2))
        (low1 (range-low ct1)) (low2 (range-low ct2))
        (lxp1 (range-low-exclusive-p ct1))
        (lxp2 (range-low-exclusive-p ct2))
        (high1 (range-high ct1)) (high2 (range-high ct2))
        (hxp1 (range-high-exclusive-p ct1))
        (hxp2 (range-high-exclusive-p ct2)))
    (values
     (or (not (eq rk1 rk2))
         (and high1 low2
              (or (< high1 low2) (and (= high1 low2) (or hxp1 lxp2))))
         (and high2 low1
              (or (< high2 low1) (and (= high2 low1) (or hxp2 lxp1)))))
     t)))

(defmethod cofinitep ((ct range)) (values nil t))

(defmethod negate ((ct range))
  ;; (not (real x (y))) = (or (not real) (real * (x)) (real y *))
  (let* ((kind (range-kind ct))
         (negk (negation (range kind nil nil nil nil)))
         (low (range-low ct)) (high (range-high ct))
         (lxp (range-low-exclusive-p ct)) (hxp (range-high-exclusive-p ct)))
    (cond ((and low high)
           (disjunction negk (range kind nil nil low (not lxp))
                        (range kind high (not hxp) nil nil)))
          (low (disjunction negk (range kind nil nil low (not lxp))))
          (high (disjunction negk (range kind high (not hxp) nil nil)))
          (t negk))))

(defmethod conjoin/2 ((ct1 range) (ct2 range))
  (if (eq (range-kind ct1) (range-kind ct2))
      (multiple-value-bind (low lxp)
          (let ((low1 (range-low ct1)) (low2 (range-low ct2))
                (lxp1 (range-low-exclusive-p ct1))
                (lxp2 (range-low-exclusive-p ct2)))
            (cond ((not low1) (values low2 lxp2))
                  ((not low2) (values low1 lxp1))
                  ((< low1 low2) (values low2 lxp2))
                  ((< low2 low1) (values low1 lxp1))
                  (t (values low1 (or lxp1 lxp2)))))
        (multiple-value-bind (high hxp)
            (let ((high1 (range-high ct1)) (high2 (range-high ct2))
                  (hxp1 (range-high-exclusive-p ct1))
                  (hxp2 (range-high-exclusive-p ct2)))
              (cond ((not high1) (values high2 hxp2))
                    ((not high2) (values high1 hxp1))
                    ((< high1 high2) (values high1 hxp1))
                    ((< high2 high1) (values high2 hxp2))
                    (t (values high1 (or hxp1 hxp2)))))
          (range (range-kind ct1) low lxp high hxp)))
      ;; Different kinds of range - conjunction is empty
      (bot)))

(defmethod disjoin/2 ((ct1 range) (ct2 range))
  (let ((rk1 (range-kind ct1)) (rk2 (range-kind ct2))
        (low1 (range-low ct1)) (low2 (range-low ct2))
        (lxp1 (range-low-exclusive-p ct1))
        (lxp2 (range-low-exclusive-p ct2))
        (high1 (range-high ct1)) (high2 (range-high ct2))
        (hxp1 (range-high-exclusive-p ct1))
        (hxp2 (range-high-exclusive-p ct2)))
    ;; If the range kinds don't match, give up.
    (unless (eq rk1 rk2) (return-from disjoin/2 (call-next-method)))
    ;; If ct2 has a lesser infinum, swap.
    (when (or (not low2)
              (and low1 (< low2 low1)))
      (rotatef low1 low2) (rotatef lxp1 lxp2)
      (rotatef high1 high2) (rotatef hxp1 hxp2))
    ;; Actually try to merge ranges.
    (cond
      ((or (not high1) (not low2)
           (> high1 low2)
           (and (= high1 low2)
                (or (not hxp1) (not lxp2))))
       (multiple-value-bind (low lxp)
           (cond ((not low1) (values low1 lxp1))
                 ((not low2) (values low2 lxp2))
                 ((< low1 low2) (values low1 lxp1))
                 ((< low2 low1) (values low2 lxp2))
                 (t (values low1 (and lxp1 lxp2))))
         (multiple-value-bind (high hxp)
             (cond ((not high1) (values high1 hxp1))
                   ((not high2) (values high2 hxp2))
                   ((< high1 high2) (values high2 hxp2))
                   ((< high2 high1) (values high1 hxp1))
                   (t (values high1 (and hxp1 hxp2))))
           (range rk1 low lxp high hxp))))
      ;; We can merge integer ranges that are off by one,
      ;; e.g. (or (integer 1 5) (integer 6 10)) = (integer 1 10).
      ((and (eq rk1 'integer)
            high1 low2 ; already covered by the above, but let's be clear
            (not hxp1) (not lxp2)
            (= (1+ high1) low2))
       (range rk1 low1 lxp1 high2 hxp2))
      (t ;; Ranges are not contiguous - give up
       (call-next-method)))))

(defmethod subtract ((ct1 range) (ct2 range))
  (let ((rk1 (range-kind ct1)) (rk2 (range-kind ct2))
        (low1 (range-low ct1)) (low2 (range-low ct2))
        (lxp1 (range-low-exclusive-p ct1))
        (lxp2 (range-low-exclusive-p ct2))
        (high1 (range-high ct1)) (high2 (range-high ct2))
        (hxp1 (range-high-exclusive-p ct1))
        (hxp2 (range-high-exclusive-p ct2)))
    (cond ((not (eq rk1 rk2)) ct1)
          ((and low1 high2
                (or (< high2 low1) (and (= high2 low1) (or hxp2 lxp1))))
           ;; ct2 is too negative to overlap with ct1
           ct1)
          ((and high1 low2
                (or (> low2 high1) (and (= low2 high1) (or lxp2 hxp1))))
           ;; ct2 is too positive to overlap with ct1
           ct1)
          ;; ct2 overlaps ct1, so we actually need to do something here.
          ((or (not low2)
               (and low1 (or (< low2 low1)
                             (and (= low2 low1) (or lxp1 (not lxp2))))))
           (if (or (not high2)
                   (and high1 (or (> high2 high1)
                                  (and (= high2 high1) (or hxp1 (not hxp2))))))
               ;; ct1 is a strict subrange of ct1
               (bot)
               ;; ct2's low is <= that of ct1, so chop off the low end of ct1.
               (range rk1 high2 (not hxp2) high1 hxp1)))
          ((or (not high2)
               (and high1 (or (> high2 high1)
                              (and (= high2 high1) (or hxp1 (not hxp2))))))
           ;; ct2's high is >= that of ct1, so chop off the high end of ct1.
           (range rk1 low1 lxp1 low2 (not lxp2)))
          (t
           ;; ct2 is a strict subrange of ct1
           (disjunction (range rk1 low1 lxp1 low2 (not lxp2))
                        (range rk1 high2 (not hxp2) high1 hxp1))))))

(defmethod unparse ((ct range))
  (let* ((kind (range-kind ct))
         (low (range-low ct)) (high (range-high ct))
         (ulow (cond ((not low) '*)
                     ((range-low-exclusive-p ct) (list low))
                     (t low)))
         (uhigh (cond ((not high) '*)
                      ((range-high-exclusive-p ct) (list high))
                      (t high)))
         (rest (if (eq uhigh '*)
                   (if (eq ulow '*)
                       nil
                       (list ulow))
                   (list ulow uhigh))))
    ;; print fixnum nicely
    (when (and (eq kind 'integer)
               (eql low most-negative-fixnum) (eql high most-positive-fixnum))
      (return-from unparse 'fixnum))
    ;; general case
    (if (eq kind 'ratio) ; no extended ratio type in CL, so we do stupid things
        (if rest
            `(and (not integer)
                  ,@(if rest `((rational ,@rest)) '(rational)))
            'ratio)
        (if rest `(,kind ,@rest) kind))))
