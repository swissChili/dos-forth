(defvar fth-mode-hook nil)

(defvar fth-mode-map
  (make-keymap)
  "fth-mode keymap.")

;;;#autoload
(add-to-list 'auto-mode-alist '("\\.f" . fth-mode))

(defconst fth-font-lock-keywords-1
  (list (regexp-opt (cons '("if" ":" ";" "then" "loop" "do" "?do" "while" "until" "begin") 'font-lock-builtin-face)))
  "Highlighting for fth-mode.")

(defvar fth-mode-syntax-table
  (let (st (make-syntax-table))
    (modify-syntax-entry ?_ "w" st)
    (modify-syntax-entry ?- "w" st)))

(defun fth-mode ()
  "Major mode for editing Forth code."
  (interactive)
  (kill-all-local-variables)
  (set-syntax-table fth-mode-syntax-table)
  (use-local-map fth-mode-map)
  (set (make-local-variable 'font-lock-defaults) '(fth-font-lock-keywords-1))
  (setq major-mode 'fth-mode)
  (setq mode-name "4th")
  (run-hooks 'fth-mode-hook))

(provide 'fth-mode)
