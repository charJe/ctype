(defsystem :ctype-tfun
  :description "Derived function return types for Common Lisp."
  :license "BSD"
  :author "Bike <aeshtaer@gmail.com>"
  :depends-on (:ctype :alexandria)
  :components
  ((:file "packages")
   (:file "util" :depends-on ("packages"))
   (:file "tfun" :depends-on ("packages"))
   (:file "data-and-control-flow" :depends-on ("util" "tfun" "packages"))
   (:file "numbers" :depends-on ("util" "tfun" "packages"))
   (:file "conses" :depends-on ("util" "tfun" "packages"))
   (:file "arrays" :depends-on ("util" "tfun" "packages"))))
