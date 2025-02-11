;;; link-hint.lisp --- functions to enable link hinting and navigation
;;; This file's parenscript is licensed under license documents/external/LICENSE1

(in-package :next)

(define-parenscript add-element-hints ()
  (defun qsa (context selector)
    "Alias of document.querySelectorAll"
    (ps:chain context (query-selector-all selector)))
  (defun code-char (n)
    "Alias of String.fromCharCode"
    (ps:chain -string (from-char-code n)))
  (defun hint-determine-position (rect)
    "Determines the position of a hint according to the element"
    (ps:create :top  (+ (ps:@ window page-y-offset) (ps:@ rect top))
               :left (+ (ps:@ window page-x-offset) (- (ps:@ rect left) 20))))
  (defun hint-create-element (element hint)
    "Creates a DOM element to be used as a hint"
    (ps:let* ((rect (ps:chain element (get-bounding-client-rect)))
              (position (hint-determine-position rect))
              (element (ps:chain document (create-element "span"))))
      (setf (ps:@ element class-name) "next-element-hint")
      (setf (ps:@ element style) (ps:lisp (box-style (current-buffer))))
      (setf (ps:@ element style position) "absolute")
      (setf (ps:@ element style left) (+ (ps:@ position left) "px"))
      (setf (ps:@ element style top) (+ (ps:@ position top) "px"))
      (setf (ps:@ element text-content) hint)
      element))
  (defun hint-add (element hint)
    "Adds a hint on a single element"
    (ps:let ((hint-element (hint-create-element element hint)))
      (ps:chain document body (append-child hint-element))
      hint-element))
  (defun hints-add (elements)
    "Adds hints on elements"
    (ps:let* ((elements-length (length elements))
              (hints (hints-generate elements-length)))
      (ps:chain -j-s-o-n
                (stringify
                 (loop for i from 0 to (- elements-length 1)
                       collect (list
                                (ps:@ (hint-add (elt elements i) (elt hints i)) inner-text)
                                (ps:@ (elt elements i) href)))))))
  (defun hints-determine-chars-length (length)
    "Finds out how many chars long the hints must be"
    (ps:let ((i 1))
      ;; 26 chars in alphabet
      (loop while (> length (expt 26 i))
            do (incf i))
      i))
  (defun hints-generate (length)
    "Generates hints that will appear on the elements"
    (strings-generate length (hints-determine-chars-length length)))
  (defun strings-generate (length chars-length)
    "Generates strings of specified length"
    (ps:let ((minimum (1+ (ps:chain -math (pow 26 (- chars-length 1))))))
      (loop for i from minimum to (+ minimum length)
            collect (string-generate i))))
  (defun string-generate (n)
    "Generates a string from a number"
    (if (>= n 0)
        (+ (string-generate (floor (- (/ n 26) 1)))
           (code-char (+ 65
                         (rem n 26)))) ""))
  (hints-add (qsa document (list "a"))))

(define-parenscript %remove-element-hints ()
  (defun hints-remove-all ()
    "Removes all the elements"
    (ps:dolist (element (qsa document ".next-element-hint"))
      (ps:chain element (remove))))
  (hints-remove-all))

(defun remove-element-hints ()
  (%remove-element-hints
   :buffer (callback-buffer (current-minibuffer))))

(defmacro query-hints (prompt (symbol) &body body)
  `(with-result* ((elements-json (add-element-hints))
                  (selected-hint (read-from-minibuffer
                                  (make-minibuffer
                                   :input-prompt ,prompt
                                   :history nil
                                   :cleanup-function #'remove-element-hints))))
     (let* ((element-hints (cl-json:decode-json-from-string elements-json))
            (,symbol (cadr (assoc selected-hint element-hints :test #'equalp))))
       (when ,symbol
         ,@body))))

(define-command follow-hint ()
  "Show a set of element hints, and go to the user inputted one in the
currently active buffer."
  (query-hints "Go to element:" (selected-element)
    (set-url selected-element :buffer (current-buffer)
                           :raw-url-p t)))

(define-deprecated-command go-anchor ()
  "Deprecated by `follow-hint'."
  (follow-hint))

(define-command follow-hint-new-buffer ()
  "Show a set of element hints, and open the user inputted one in a new
buffer (not set to visible active buffer)."
  (query-hints "Open element in new buffer:" (selected-element)
    (let ((new-buffer (make-buffer)))
      (set-url selected-element :buffer new-buffer
                             :raw-url-p t))))

(define-deprecated-command go-anchor-new-buffer ()
  "Deprecated by `follow-hint-new-buffer'."
  (follow-hint-new-buffer))

(define-command follow-hint-new-buffer-focus ()
  "Show a set of element hints, and open the user inputted one in a new
visible active buffer."
  (query-hints "Go to element in new buffer:" (selected-element)
    (let ((new-buffer (make-buffer)))
      (set-url selected-element :buffer new-buffer :raw-url-p t)
      (set-current-buffer new-buffer))))

(define-deprecated-command go-anchor-new-buffer-focus ()
  "Deprecated by `follow-hint-new-buffer-focus'."
  (follow-hint-new-buffer-focus))

(define-command copy-hint-url ()
  "Show a set of element hints, and copy the URL of the user inputted one."
  (query-hints "Copy element URL:" (selected-element)
    (trivial-clipboard:text selected-element)))

(define-deprecated-command copy-anchor-url ()
  "Deprecated by `copy-hint-url'."
  (copy-hint-url))
