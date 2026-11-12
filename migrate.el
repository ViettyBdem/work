;;; migrate.el --- format 1 -> format 2 (Given/When/Then) for sifox-case.el  -*- lexical-binding: t; coding: utf-8; -*-

;; Читает базу формата 1 (:pre / :steps как простые строки / :expected одним
;; текстом) и пишет базу формата 2 (граф, шаги (:given :when :then)).
;;
;;   emacs -Q --batch -L . -l migrate \
;;     --eval '(sifox/tc-migrate-file "sifox-cases.eld" "sifox-cases-v2.eld")'
;;
;; Правила переноса:
;;   Given  - прежние предусловия (:pre), только контекст перед первым действием;
;;   When   - одно действие шага; Then - его наблюдаемый результат;
;;   детали из старого :expected становятся шагами-проверками (Then без When),
;;   чтобы их отклонение не блокировало детей;
;;   :access - по самой сильной операции кейса (r/w/x);
;;   приоритет: High->1, Medium->2, Low->3; severity по старому :kind;
;;   результат прогона: заметки об отклонениях идут на шаг с проверкой
;;   ожидаемого, остальное - ok; «Не запускался» остаётся нетронутым;
;;   родители: цепочка внутри модуля (первые - самые сильные действия).
;;
;; После переноса файл стоит править руками: он рабочий, а не финальный.

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defun sifox/tc--read-file (file)
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8))
      (insert-file-contents file))
    (read (current-buffer))))

(defun sifox/tc-migrate-prefix (id)
  "Module prefix of case ID, e.g. \"QFRM\" from \"QFRM-004\"."
  (replace-regexp-in-string "-[0-9]+\\'" "" id))

(defun sifox/tc-migrate-priority (p)
  (pcase p ("High" "1") ("Medium" "2") (_ "3")))

(defun sifox/tc-migrate-severity (kind)
  "Severity from the old :kind."
  (cond ((equal kind "Отображение") "S3 Значительный")
        ((equal kind "Негативный")  "S3 Значительный")
        ((equal kind "Валидация")   "S3 Значительный")
        (t "S2 Критический")))

(defconst sifox/tc-migrate--x
  "позвон|набрать номер|отклон|сброс|заверш|выход|увольн|разблок|блокир|архивир|восстанов|удал|сохранить|создать|добав|отправить|перемещ|подтверд|открыть очередь на редактирование кликом|нажать «сохранить|нажать «создать|нажать «архивировать|нажать «восстановить|нажать «удалить|нажать «закрыть|нажать «отправить|нажать «переместить"
  "Regexp of steps with consequences beyond the record (level x).")

(defconst sifox/tc-migrate--w
  "ввести|выбрать|изменить|переключ|нажать|клик|отметить|очистить|стереть|поставить|вставить|установить|снять|отказать|скрыть|показать|перетащ|развернуть|раскрыть|сыграть|проиграть|пауза|тест|дописать|отключить|включить|задать|вызвать|ожидать|прослушать"
  "Regexp of steps that enter or change data (level w).")

(defun sifox/tc-migrate-access (step)
  "Operation level of STEP (a plain string): x, w or r."
  (let ((s (downcase step)))
    (cond ((string-match-p sifox/tc-migrate--x s) 'x)
          ((string-match-p sifox/tc-migrate--w s) 'w)
          (t 'r))))

(defun sifox/tc-migrate-sentences (text)
  "Split TEXT into short check items: lines first, long lines by sentences."
  (let (out)
    (dolist (line (split-string (or text "") "\n" t "[ \t]*"))
      (let ((line (string-trim line)))
        (if (<= (length line) 160)
            (push line out)
          (setq out (append out
                            (delq nil
                                  (mapcar #'string-trim
                                          (split-string line "\\. " t))))))))
    (nreverse (delete-dups out))))

(defun sifox/tc-migrate--action-then (st last)
  "Short interim Then for action step ST; LAST non-nil - the final action."
  (cond (last "Действие выполнено, результат проверяется следующими шагами.")
        ((eq 'r (sifox/tc-migrate-access st))
         "Действие выполнено, экран доступен для следующего шага.")
        (t "Действие выполнено без ошибок.")))

(defun sifox/tc-migrate-steps (pre steps expected)
  "Old PRE / STEPS / EXPECTED -> new :steps.
Each action keeps its own When and gets a short interim Then; the details
of the old expected text become check-only steps (Then without a When), so
their deviation does not block the children."
  (let* ((checks (sifox/tc-migrate-sentences expected))
         (gwt nil))
    (when (and pre (not (string-empty-p (string-trim pre))))
      (push (list :given (string-trim pre)) gwt))
    ;; every action is one step with its own When
    (seq-map-index
     (lambda (st i)
       (push (list :when st
                   :then (sifox/tc-migrate--action-then st (= i (1- (length steps)))))
             gwt))
     steps)
    ;; the observable outcome: one check per item, at most three items
    (dolist (ck (seq-take checks 3))
      (push (list :then ck) gwt))
    (when (> (length checks) 3)
      (push (list :then "Прочие детали соответствуют требованиям") gwt))
    ;; a case must have at least one Then
    (unless (cl-some (lambda (s) (plist-get s :then)) gwt)
      (push (list :then "Ожидаемое поведение соответствует требованиям") gwt))
    (mapcar (lambda (s)
              (cl-loop for (k v) on s by #'cddr
                       when (and (stringp v) (not (string-empty-p v)))
                       append (list k v)))
            (nreverse gwt))))

(defun sifox/tc-migrate-actual (steps actual status)
  "Old ACTUAL strings -> (:state :note) pairs for new STEPS.
Deviation notes go to the first check-only step; if everything matched, all
steps are ok.  «Не запускался» keeps every step todo."
  (let ((notes (delq nil
                     (mapcar (lambda (a)
                               (let ((s (string-trim (or a ""))))
                                 (unless (or (string-empty-p s)
                                             (string-match-p "\\`Совпадает" s))
                                   s)))
                             (if (listp actual) actual (list actual)))))
         (todo (equal status "Не запускался")))
    (cl-loop for s in steps
             for has-when = (plist-get s :when)
             collect (cond (todo (list :state 'todo :note ""))
                           ((and notes (null has-when))
                            (prog1 (list :state 'fail :note (string-join notes "\n"))
                              (setq notes nil)))
                           (t (list :state 'ok :note ""))))))

(defun sifox/tc-migrate-case (c)
  "Format 1 case C -> authored format 2 node (without :parents)."
  (let* ((status (plist-get c :status))
         (steps (sifox/tc-migrate-steps (plist-get c :pre)
                                        (plist-get c :steps)
                                        (plist-get c :expected)))
         (actual (sifox/tc-migrate-actual steps (plist-get c :actual) status))
         (access (if (equal status "Пройден") 'r
                   (apply #'max (mapcar (lambda (s)
                                          (cdr (assq (sifox/tc-migrate-access s)
                                                     '((r . 0) (w . 1) (x . 2))))))
                                  (plist-get c :steps))))
         (roles (let ((m (plist-get c :module)))
                  (cond ((string-prefix-p "Личный кабинет" m) '("Оператор"))
                        ((member m '("Телефония в браузере (WebRTC) и устройства"
                                     "Набор номера и исходящий звонок"
                                     "Входящий звонок и панель разговора"
                                     "Послевызовная обработка (ACW)"
                                     "История звонков"
                                     "Карточка звонка"
                                     "Мини-плеер записи"
                                     "Обратные звонки"
                                     "Статус работы на линии"))
                         '("Оператор"))
                        (t '("Руководитель"))))))
    (list :id (plist-get c :id)
          :module (plist-get c :module)
          :title (plist-get c :title)
          :access (car (rassoc access '((r . 0) (w . 1) (x . 2))))
          :roles roles
          :priority (sifox/tc-migrate-priority (plist-get c :priority))
          :severity (sifox/tc-migrate-severity (plist-get c :kind))
          :steps steps
          :actual actual
          :status status
          :comment (or (plist-get c :comment) ""))))

(defun sifox/tc-migrate-chain (nodes)
  "Give NODES parents along chains of the same module.
Stronger operations (w, x) continue the chain of the previous node; a
display/read node starts a new branch under the module root, so reading
cases do not depend on each other."
  (let ((rank '((r . 0) (w . 1) (x . 2)))
        (root-by-mod (make-hash-table :test #'equal))
        (prev (make-hash-table :test #'equal)))
    (dolist (n nodes)
      (let* ((mod (plist-get n :module))
             (id (plist-get n :id))
             (root (gethash mod root-by-mod))
             (p (gethash mod prev))
             (par (cond ((null root) nil)
                        ((and p (> (cdr (assq (plist-get n :access) rank)) 0)
                              (>= (cdr (assq (plist-get n :access) rank))
                                  (cdr (assq (plist-get p :access) rank))))
                         (list p))
                        (t (list root)))))
        (puthash mod (or root id) root-by-mod)
        (puthash mod id prev)
        (setf (plist-get n :parents) par)))))

(defun sifox/tc-migrate-file (in-file out-file)
  "Write the format 2 database OUT-FILE from the format 1 database IN-FILE."
  (interactive "fБаза формата 1: "fНовая база формата 2: ")")
  (let* ((db (sifox/tc--read-file in-file))
         (cases (mapcar #'cdr (plist-get db :cases)))
         (nodes (mapcar #'sifox/tc-migrate-case cases)))
    (when (eql (plist-get db :format) 2)
      (error "%s уже формат 2" in-file))
    (sifox/tc-migrate-chain nodes)
    (with-temp-file out-file
      (let ((print-length nil) (print-level nil) (coding-system-for-write 'utf-8-unix))
        (insert ";; -*- mode: lisp-data; coding: utf-8 -*-\n"
                ";; UAT test cases (graph, format 2), see sifox-case.el\n")
        (pp (list :format 2 :cases
                  (cl-loop for n in nodes collect (cons (plist-get n :id) n)))
            (current-buffer))))
    (message "%s: %d кейсов -> %s" in-file (length nodes) out-file)
    (length nodes)))

(provide 'migrate)
;;; migrate.el ends here
