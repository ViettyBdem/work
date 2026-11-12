;;; sifox-case-build.el --- build the format 2 database from an authored nodes file  -*- lexical-binding: t; -*-

;; Авторский файл - список узлов (plist) с полями :id :module :title :access
;; :setup :roles :parents :priority :severity :steps и, если результат
;; переносится из прежних прогонов, :actual и/или :status.
;;
;;   emacs -Q --batch -L . -l sifox-case-build \
;;     --eval '(sifox/tc-build "pilot-nodes.eld" "data/sifox-cases.eld")'
;;
;; Добавляет служебные поля, считает статус по :actual, проверяет граф и
;; пишет базу.  Существующий файл базы заменяется.

(require 'sifox-case)

(defun sifox/tc-build-case (node now)
  "Database case from the authored NODE."
  (sifox/tc-new-case node now))

(defun sifox/tc-build (nodes-file db-file)
  "Write DB-FILE (format 2) from the authored NODES-FILE.
Return the number of cases."
  (let* ((nodes (with-temp-buffer
                  (let ((coding-system-for-read 'utf-8)) (insert-file-contents nodes-file))
                  (read (current-buffer))))
         (ids (mapcar (lambda (n) (plist-get n :id)) nodes))
         (dups (seq-filter (lambda (id) (> (cl-count id ids :test #'equal) 1)) ids))
         (now (sifox/rp-now))
         (sifox/tc-db-file db-file)
         (sifox/tc--db (list :format 2 :cases nil)) (sifox/tc--db-mtime nil) (sifox/tc--index nil))
    (when dups (error "Повторяются ID: %s" (string-join (delete-dups dups) ", ")))
    (when (file-exists-p db-file) (delete-file db-file))
    (sifox/tc-db-put-many (mapcar (lambda (n) (sifox/tc-build-case n now)) nodes))
    (let ((problems (sifox/tc-graph-problems)))
      (when problems
        (error "Проблемы графа:\n%s" (string-join problems "\n"))))
    (message "%s: %d кейсов" db-file (length nodes))
    (length nodes)))

(provide 'sifox-case-build)
;;; sifox-case-build.el ends here
