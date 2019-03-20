;;;; JSON to CSV script

(defclass restaurant ()
  ((restaurant_id
    :accessor rstnt-id
    :initform "error")
   (name
    :accessor rstnt-name
    :initform "error")
   (building
    :accessor rstnt-building
    :initform "error")
   (coord_x
    :accessor rstnt-x
    :initform "error")
   (coord_y
    :accessor rstnt-y
    :initform "error")
   (street
    :accessor rstnt-street
    :initform "error")
   (zipcode
    :accessor rstnt-zipcode
    :initform "error")
   (borough
    :accessor rstnt-borough
    :initform "error")
   (cuisine
    :accessor rstnt-cuisine
    :initform "error")))

(defclass grade ()
  ((restaurant_id
    :accessor grade-rstnt-id
    :initform "error")
   (date
    :accessor grade-date
    :initform "error")
   (grade
    :accessor grade-grade
    :initform "error")
   (score
    :accessor grade-score
    :initform "error")))

(defparameter *rest*
  (make-instance 'restaurant))

(defparameter *grade*
  (make-instance 'grade))

(defun split-string (char string)
  "returns a list of strings"
  (loop :for i :from 0 :to (- (length string) 1)
        :with last-char = 0
        :if (char-equal char (char string i))
          :collect (prog1 (subseq string last-char i)
                     (setf last-char (+ i 1)))
        :if (= i (- (length string) 1))
          :collect (subseq string last-char (length string))))

;(format t "~a" (split-string #\Space "hello i am bentham"))

(defun sentence (splitted start)
  "returns a string that's a sentence composed of several words in a list of strings"
  (loop :for i :from (+ start 1) :to (list-length splitted)
        :with result = (nth start splitted)
        :until (or (string-equal (nth i splitted) "\"restaurant_id\":")
                   (string-equal (nth i splitted) "\"zipcode\":"))
        :do (setf result (format nil "~a ~a" result (nth i splitted)))
        :finally (return result)))

;(format t "~a" (sentence (list "hello" "I" "am" "bentham" "\"restaurant_id\":") 0))

(defun grade-process (string rstnt-id stream)
  "reads a json line and returns csv lines for grade"
  (let ((splitted (split-string #\Space string)))
    (loop :for n :from 0 :to (list-length splitted)
          :do (cond ((string-equal (nth n splitted) "[{\"date\":")
                     (progn (setf *grade* (make-instance 'grade))
                            (setf (grade-rstnt-id *grade*) rstnt-id)))
                    ((string-equal (nth n splitted) "{\"$date\":")
                     (setf (grade-date *grade*) (string-trim " }," (nth (+ n 1) splitted))))
                    ((string-equal (nth n splitted) "\"grade\":")
                     (setf (grade-grade *grade*) (string-trim " \"," (nth (+ n 1) splitted))))
                    ((string-equal (nth n splitted) "\"score\":")
                     (progn (setf (grade-score *grade*) (string-trim " }]," (nth (+ n 1) splitted)))
                            (format stream
                                    "~a, ~a, ~a, ~a~%"
                                    (grade-rstnt-id *grade*)
                                    (grade-date *grade*)
                                    (grade-grade *grade*)
                                    (grade-score *grade*))))))))

(defun restaurant-process (string stream)
  "reads a json line and returns a csv line for restaurant"
  (progn (setf *rest* (make-instance 'restaurant))
         (let ((splitted (split-string #\Space string)))
           (loop :for i :from 0 :to (list-length splitted)
                 :do (cond ((string-equal (nth i splitted) "\"restaurant_id\":")
                            (setf (rstnt-id *rest*) (string-trim " \"{}" (nth (+ i 1) splitted))))
                           ((string-equal (nth i splitted) "\"name\":")
                            (setf (rstnt-name *rest*) (string-trim " \"," (sentence splitted (+ i 1)))))
                           ((string-equal (nth i splitted) "{\"building\":")
                            (setf (rstnt-building *rest*) (string-trim " \"," (nth (+ i 1) splitted))))
                           ((string-equal (nth i splitted) "\"coordinates\"")
                            (progn (setf (rstnt-x *rest*) (string-trim " []{}," (nth (+ i 2) splitted)))
                                   (setf (rstnt-y *rest*) (string-trim " []{}," (nth (+ i 3) splitted)))))
                           ((string-equal (nth i splitted) "\"street\":")
                            (setf (rstnt-street *rest*) (string-trim " \"," (sentence splitted (+ i 1)))))
                           ((string-equal (nth i splitted) "\"zipcode\":")
                            (setf (rstnt-zipcode *rest*) (string-trim " \"{}," (nth (+ i 1) splitted))))
                           ((string-equal (nth i splitted) "\"borough\":")
                            (setf (rstnt-borough *rest*) (string-trim " \"," (nth (+ i 1) splitted))))
                           ((string-equal (nth i splitted) "\"cuisine\":")
                            (setf (rstnt-cuisine *rest*) (string-trim " \"," (nth (+ i 1) splitted))))))
           (format stream
                   "~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a, ~a~%"
                   (rstnt-id *rest*)
                   (rstnt-name *rest*)
                   (rstnt-building *rest*)
                   (rstnt-x *rest*)
                   (rstnt-y *rest*)
                   (rstnt-street *rest*)
                   (rstnt-zipcode *rest*)
                   (rstnt-borough *rest*)
                   (rstnt-cuisine *rest*)))
         (rstnt-id *rest*)))

(with-open-file (stream-restaurants "./restaurants.csv"
                                   :direction :output
                                   :if-exists :supersede)
  (with-open-file (stream-grades "./grades.csv"
                                :direction :output
                                :if-exists :supersede)
    (let ((in (open "./restaurants.json"
                    :if-does-not-exist (format t "doesn't exist"))))
      (when in
        (loop :for line = (read-line in nil)
              :while line
              :do (grade-process line (restaurant-process line stream-restaurants) stream-grades))
        (close in)))))

(format t "~%done")
