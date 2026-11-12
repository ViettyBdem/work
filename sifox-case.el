;;; sifox-case.el --- UAT test cases as a graph: lisp-data, org headings, JSON  -*- lexical-binding: t; -*-

;; Тест-кейсы UAT рядом с репортами из `sifox-report-common.el'.
;; Формат данных 2: кейсы - узлы графа, шаги - Given / When / Then.
;;
;; ---------------------------------------------------------------------------
;; Модель
;; ---------------------------------------------------------------------------
;;
;; У кейса нет предусловий.  Вместо них - родители (:parents): кейс начинается
;; в состоянии, в котором закончились родители.
;;   - первый родитель - «где мы находимся» (экран, с которого начинаем);
;;   - остальные - «что уже должно быть сделано» (данные, которые должны быть).
;; У кейса может быть несколько детей - это разные продолжения одного
;; состояния.  Состояние, которое нельзя получить никаким кейсом (нет свободных
;; номеров, время суток, запись только в Active Directory) или для подготовки
;; которого нет проверяемых ожиданий, описывается кейсом-подготовкой
;; (:setup t, ID вида QFRM-S01): он тоже родитель, но в прогресс не входит.
;;
;; Уровень операции (:access), от наименьших прав к наибольшим:
;;   r - только смотрит и переходит по экранам, ничего не вводит;
;;   w - вводит или меняет данные (сохранённые или нет);
;;   x - запускает операцию с последствиями за пределами записи
;;       (архив/восстановление, звонок, блокировка, увольнение).
;; Корень модуля (кейс без родителя в своём модуле) должен быть уровня r.
;;
;; Шаг - (:given "…" :when "…" :then "…").  :then (ожидаемое) обязателен;
;; :given и :when можно опустить - тогда шаг проверяет ещё одно следствие
;; предыдущего действия.  Фактическое поведение зеркалит шаги по номерам:
;; (:state ok|fail|todo :note "…").
;;
;; Что блокирует детей.  Шаг с When - действие: если оно не сработало, детям
;; не с чего начинать.  Шаг только с Then - проверка детали (текст, цвет,
;; тост): её отклонение детей не блокирует.  Поэтому кейс, от которого зависят
;; другие («шлюз»), делает действие и проверяет только то, что нужно детям, а
;; детали выносятся в шаги-проверки или в отдельные кейсы-листья.  Детей
;; блокирует: «Заблокирован»; «Не пройден» с отклонением на шаге-действии;
;; «Не пройден», поставленный вручную без отмеченных отклонений.
;;
;; ---------------------------------------------------------------------------
;; Установка
;; ---------------------------------------------------------------------------
;;
;;   (add-to-list 'load-path "~/sifox/lisp")   ; там же sifox-report-common.el
;;   (require 'sifox-case)
;;   (setq sifox/tc-db-file "~/sifox/data/sifox-cases.eld")
;;   ;; по желанию: смена TODO-состояния кейса сразу пишется в данные
;;   (add-hook 'org-after-todo-state-change-hook #'sifox/tc-on-todo-change)
;;
;; ---------------------------------------------------------------------------
;; Работа
;; ---------------------------------------------------------------------------
;;
;; 1. Заголовки.  В org-файле встать на заголовок и вызвать
;;      M-x sifox/tc-insert-cases        - все кейсы
;;      C-u M-x sifox/tc-insert-cases    - кейсы одного модуля
;;    Появится заголовок на модуль, под ним кейсы; кейс вложен в своего
;;    первого родителя, если тот в том же модуле, остальные родители - ссылки
;;    в строке «После:».  Кейсы, которые уже есть в буфере, пропускаются.
;;
;;      *** TODO [#A] QUE-007: Открыть очередь кликом по строке     :r:
;;      После: [[#QUE-004][QUE-004]] Строки списка очередей
;;      **** Ожидаемое поведение
;;      1. [ ] *When* Нажать на строку любой очереди
;;         *Then* Открывается экран «РЕДАКТИРОВАНИЕ ОЧЕРЕДИ»
;;      **** Фактическое поведение [0/1]
;;      1. [ ]
;;      **** Комментарий тестировщика
;;
;; 2. Прогон.  В «Фактическом поведении» пункт N отвечает шагу N:
;;      [X]            - совпало с Then;
;;      [-] текст  или  [ ] текст  - отклонение, текст - что было на самом деле;
;;      [ ] без текста - шаг ещё не проверен.
;;    Галочки в «Ожидаемом поведении» - пометка «шаг выполнен», в данные не
;;    пишутся.  Затем
;;      M-x sifox/tc-sync   - записать кейс у точки в данные
;;    Статус считается по пунктам: есть отклонение - «Не пройден» (FAIL), все
;;    совпали - «Пройден» (PASS).  Вручную (C-c C-t):
;;      PASS    - отмечает все пункты [X] («прошёл, замечаний нет» - одно нажатие);
;;      BLOCKED, SKIP, FAIL без отмеченных отклонений - сохраняются как есть.
;;    С хуком из «Установки» синхронизация идёт сама при смене состояния.
;;
;; 3. Репорт.  На кейсе с отклонением
;;      M-x sifox/tc-report - INC/BUG из кейса: шаги воспроизведения собираются
;;                            по цепочке первых родителей, ожидаемое и
;;                            фактическое - из шагов с отклонением.
;;
;; 4. Новый кейс.  Встать на кейс-родитель и вызвать
;;      M-x sifox/tc-new-child       - новый кейс-ребёнок
;;      C-u M-x sifox/tc-new-child   - новый кейс-подготовка
;;    Спросит название, уровень операции, приоритет, severity, других
;;    родителей и шаги (Given, When, Then; пустой Then заканчивает шаги).
;;    Кейс получает следующий свободный ID модуля родителя, записывается в
;;    `sifox/tc-db-file' и вставляется последним ребёнком в заголовок родителя.
;;
;; 5. Прогресс:  M-x sifox/tc-progress (C-u - один модуль); подготовка не
;;    считается.  По приоритету: (sifox/tc-priority-progress "1").
;;
;; 6. Проверка графа:  M-x sifox/tc-validate - неизвестные родители, циклы,
;;    корень модуля не уровня r, шаг без Then, длина :actual.
;;
;; 7. Выгрузка:
;;      M-x sifox/tc-json-export  - граф в JSON (формат ниже)
;;      M-x sifox/tc-tsv-export   - плоский TSV для uat-progress.awk и CI
;;
;; ---------------------------------------------------------------------------
;; Данные
;; ---------------------------------------------------------------------------
;;
;; `sifox/tc-db-file' - lisp-data: один plist, читается `read', не исполняется.
;;
;;   (:format 2
;;    :cases (("QUE-007" :id "QUE-007" :module "Список очередей"
;;             :title "Открыть очередь кликом по строке"
;;             :access r                  ; r, w или x
;;             :setup nil                 ; t - кейс-подготовка
;;             :roles ("Руководитель")
;;             :parents ("QUE-004")       ; первый - основной
;;             :priority "1"              ; "1" (выше) … "3"; nil у подготовки
;;             :severity "S2 Критический" ; из `sifox/rp-severities'
;;             :steps ((:when "…" :then "…") (:given "…" :when "…" :then "…"))
;;             :actual ((:state ok :note "") (:state fail :note "…"))
;;             :status "Не запускался" :comment "" :reports ("UUID" …)
;;             :created "…" :updated "…" :history ((TIME :field OLD NEW) …))
;;            …))
;;
;; JSON (`sifox/tc-json-export'):
;;
;;   {"format": 2, "generated": "…",
;;    "nodes": [{"id": "QUE-007", "module": "…", "title": "…", "access": "r",
;;               "setup": false, "roles": ["…"], "priority": 1,
;;               "effective_priority": 1, "severity": "S2 Критический",
;;               "status": "Не запускался", "parents": ["QUE-004"],
;;               "children": ["QFRM-025"], "blocking": false, "blocked_by": [],
;;               "steps": [{"n": 1, "given": null, "when": "…", "then": "…",
;;                          "gate": true, "state": "todo", "note": ""}],
;;               "comment": "", "reports": []}],
;;    "edges": [{"from": "QUE-004", "to": "QUE-007", "primary": true}],
;;    "roots": ["AUTH-001"]}
;;
;;   effective_priority - наивысший приоритет среди кейса и всех его потомков:
;;     чтобы дойти до кейса приоритета 1, нужно пройти его предков;
;;   gate - шаг-действие (есть When): его отклонение блокирует детей;
;;   blocking - кейс блокирует детей (см. «Что блокирует детей»);
;;   blocked_by - блокирующие предки.
;;
;; API для других программ:
;;   (sifox/tc-db-cases) (sifox/tc-db-get ID) (sifox/tc-db-find PRED)
;;   (sifox/tc-db-put CASE) (sifox/tc-db-put-many CASES)
;;   (sifox/tc-children ID) (sifox/tc-ancestors ID) (sifox/tc-descendants ID)
;;   (sifox/tc-path ID)        - цепочка первых родителей от корня до ID
;;   (sifox/tc-blocking-p CASE) (sifox/tc-blocked-by ID)
;;   (sifox/tc-new-case FIELDS) - кейс для базы из авторских полей
;;   (sifox/tc-next-id PARENT-ID [SETUP]) - следующий свободный ID
;;   (sifox/tc-graph-problems) - список строк с проблемами графа
;;   (sifox/tc-graph)          - граф как alist для `json-encode'
;;   (sifox/tc-render CASE LEVEL) - org-текст кейса

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'json)
(require 'org)
(require 'sifox-report-common)

(defvar org-state)  ; bound by org-todo around its hooks

;;; ---- dictionaries

(defvar sifox/tc-statuses
  '(("Не запускался" . "TODO")
    ("Пройден"       . "PASS")
    ("Не пройден"    . "FAIL")
    ("Заблокирован"  . "BLOCKED")
    ("Пропущен"      . "SKIP"))
  "Case statuses: (STATUS . ORG-KEYWORD).  The first one is the initial status.")

(defvar sifox/tc-priorities '(("1" . ?A) ("2" . ?B) ("3" . ?C))
  "Case priority -> org priority cookie; \"1\" is the highest.")

(defvar sifox/tc-access '((r . "чтение") (w . "запись") (x . "выполнение"))
  "Operation levels, from the least privilege: (SYMBOL . NAME).")

(defvar sifox/tc-setup-tag "setup"
  "Org tag and TSV type of manual setup cases.")

(defconst sifox/tc--expected-title "Ожидаемое поведение")
(defconst sifox/tc--actual-title "Фактическое поведение")
(defconst sifox/tc--comment-title "Комментарий тестировщика")

;;; ---- database

(defvar sifox/tc-db-file "data/sifox-cases.eld"
  "UAT test cases database (format 2).")

(defvar sifox/tc--db nil "Database in memory.")
(defvar sifox/tc--db-mtime nil "Modification time of the loaded file.")
(defvar sifox/tc--index nil "Cache: (DB . CHILDREN-HASH), see `sifox/tc--children-index'.")

(defun sifox/tc--db ()
  "Return the database, re-reading the file if it changed on disk."
  (let ((mtime (and (file-exists-p sifox/tc-db-file)
                    (sifox/rp--file-mtime sifox/tc-db-file))))
    (when (or (null sifox/tc--db) (not (equal mtime sifox/tc--db-mtime)))
      (let ((db (or (and mtime (sifox/rp--read-file sifox/tc-db-file))
                    (list :format 2 :cases nil))))
        (unless (eql (plist-get db :format) 2)
          (user-error "%s: формат %s, а нужен 2 (граф). Старые кейсы переносит sifox-case-migrate.el"
                      (expand-file-name sifox/tc-db-file) (plist-get db :format)))
        (setq sifox/tc--db db sifox/tc--db-mtime mtime))))
  sifox/tc--db)

(defun sifox/tc--db-save ()
  (let ((print-length nil) (print-level nil) (coding-system-for-write 'utf-8))
    (make-directory (or (file-name-directory (expand-file-name sifox/tc-db-file)) ".") t)
    (with-temp-file sifox/tc-db-file
      (insert ";; -*- mode: lisp-data; coding: utf-8 -*-\n"
              ";; UAT test cases (graph, format 2), see sifox-case.el\n")
      (pp sifox/tc--db (current-buffer))))
  (setq sifox/tc--db-mtime (sifox/rp--file-mtime sifox/tc-db-file)))

(defun sifox/tc-db-cases ()
  "All cases, in file order."
  (mapcar #'cdr (plist-get (sifox/tc--db) :cases)))

(defun sifox/tc-db-get (id)
  (cdr (assoc id (plist-get (sifox/tc--db) :cases))))

(defun sifox/tc-db-find (pred)
  (seq-filter pred (sifox/tc-db-cases)))

(defun sifox/tc-db-put-many (cases)
  "Add or replace CASES (plists with :id), keeping order; one write.  Return CASES."
  (let* ((db (sifox/tc--db))
         (alist (copy-sequence (plist-get db :cases))))
    (dolist (c cases)
      (setq c (sifox/rp--plain c))
      (let ((cell (assoc (plist-get c :id) alist)))
        (if cell (setcdr cell c)
          (setq alist (append alist (list (cons (plist-get c :id) c)))))))
    (setq sifox/tc--db (plist-put db :cases alist))
    (sifox/tc--db-save)
    cases))

(defun sifox/tc-db-put (case)
  (car (sifox/tc-db-put-many (list case))))

;;; ---- steps and status

(defun sifox/tc-normalize-actual (c)
  "The :actual of C as a list exactly as long as :steps."
  (let ((actual (plist-get c :actual)))
    (cl-loop for _ in (plist-get c :steps)
             for a = (pop actual)
             collect (list :state (or (plist-get a :state) 'todo)
                           :note (or (plist-get a :note) "")))))

(defun sifox/tc-derive-status (actual manual)
  "Status from ACTUAL (list of (:state …)) and the MANUAL status.
A deviation gives «Не пройден», all steps ok give «Пройден».  Otherwise the
checkboxes say nothing yet and MANUAL stands if it is «Не пройден»,
«Заблокирован» or «Пропущен»; a manual «Пройден» is not kept without
all steps ok."
  (let ((states (mapcar (lambda (a) (plist-get a :state)) actual))
        (initial (caar sifox/tc-statuses)))
    (cond ((memq 'fail states) "Не пройден")
          ((and states (cl-every (lambda (s) (eq s 'ok)) states)) "Пройден")
          ((member manual '("Не пройден" "Заблокирован" "Пропущен")) manual)
          (t initial))))

(defun sifox/tc-setup-p (c) (plist-get c :setup))

(defun sifox/tc-step-gate-p (step)
  "Non-nil if STEP is an action (has a When): its failure blocks the children.
A step with only a Then is a check of one more detail and blocks nothing."
  (not (string-empty-p (or (plist-get step :when) ""))))

(defun sifox/tc-blocking-p (c)
  "Non-nil if the children of case C cannot be run because of C.
That is: C is «Заблокирован»; or «Не пройден» with a deviation on an action
step (see `sifox/tc-step-gate-p'); or «Не пройден» by hand, with no
deviation marked.  A case that failed only on detail checks does not block."
  (pcase (plist-get c :status)
    ("Заблокирован" t)
    ("Не пройден"
     (let ((failed (cl-loop for s in (plist-get c :steps)
                            for a in (sifox/tc-normalize-actual c)
                            when (eq (plist-get a :state) 'fail) collect s)))
       (or (null failed) (cl-some #'sifox/tc-step-gate-p failed))))))

(defun sifox/tc-new-case (fields &optional now)
  "Database case from FIELDS (an authored plist).
Service fields are added and the status is derived from :actual."
  (let* ((c (copy-sequence fields))
         (now (or now (sifox/rp-now)))
         (actual (sifox/tc-normalize-actual c))
         (status (sifox/tc-derive-status actual (plist-get c :status))))
    (dolist (kv `((:setup ,(plist-get c :setup)) (:actual ,actual) (:status ,status)
                  (:comment ,(or (plist-get c :comment) "")) (:reports nil)
                  (:created ,now) (:updated ,now) (:history nil)))
      (setq c (plist-put c (car kv) (cadr kv))))
    c))

;;; ---- graph

(defun sifox/tc--children-index ()
  "Hash ID -> list of child ids (file order), cached per loaded database."
  (let ((db (sifox/tc--db)))
    (unless (eq (car sifox/tc--index) db)
      (let ((h (make-hash-table :test #'equal)))
        (dolist (c (sifox/tc-db-cases))
          (dolist (p (plist-get c :parents))
            (puthash p (append (gethash p h) (list (plist-get c :id))) h)))
        (setq sifox/tc--index (cons db h))))
    (cdr sifox/tc--index)))

(defun sifox/tc-children (id)
  "Ids of the cases that have ID among their parents."
  (gethash id (sifox/tc--children-index)))

(defun sifox/tc--closure (id next)
  "Ids reachable from ID by NEXT (a function ID -> ids), without ID; no duplicates."
  (let ((seen (make-hash-table :test #'equal)) (queue (funcall next id)) out)
    (while queue
      (let ((x (pop queue)))
        (unless (or (equal x id) (gethash x seen))
          (puthash x t seen)
          (push x out)
          (setq queue (append queue (funcall next x))))))
    (nreverse out)))

(defun sifox/tc-ancestors (id)
  "All ancestors of ID (through every parent), nearest first."
  (sifox/tc--closure id (lambda (x) (plist-get (sifox/tc-db-get x) :parents))))

(defun sifox/tc-descendants (id)
  (sifox/tc--closure id #'sifox/tc-children))

(defun sifox/tc-path (id)
  "Chain of first parents from the root down to ID (inclusive)."
  (let (path (seen nil))
    (while (and id (not (member id seen)))
      (push id seen)
      (push id path)
      (setq id (car (plist-get (sifox/tc-db-get id) :parents))))
    path))

(defun sifox/tc-roots ()
  "Ids of the cases without parents."
  (cl-loop for c in (sifox/tc-db-cases)
           unless (plist-get c :parents) collect (plist-get c :id)))

(defun sifox/tc-blocked-by (id)
  "Ancestors of ID that block it, see `sifox/tc-blocking-p'."
  (seq-filter (lambda (a) (let ((c (sifox/tc-db-get a))) (and c (sifox/tc-blocking-p c))))
              (sifox/tc-ancestors id)))

(defun sifox/tc-effective-priority (id)
  "Highest priority (smallest number) among ID and its descendants, or nil."
  (let ((ps (cl-loop for x in (cons id (sifox/tc-descendants id))
                     for p = (plist-get (sifox/tc-db-get x) :priority)
                     when p collect (string-to-number p))))
    (when ps (apply #'min ps))))

(defun sifox/tc--cycle-members ()
  "Ids that take part in a cycle of parents."
  (cl-loop for c in (sifox/tc-db-cases)
           for id = (plist-get c :id)
           when (member id (sifox/tc-ancestors-raw id)) collect id))

(defun sifox/tc-ancestors-raw (id)
  "Like `sifox/tc-ancestors', but ID is included when it is its own ancestor."
  (let ((seen (make-hash-table :test #'equal))
        (queue (plist-get (sifox/tc-db-get id) :parents)) out)
    (while queue
      (let ((x (pop queue)))
        (unless (gethash x seen)
          (puthash x t seen)
          (push x out)
          (setq queue (append queue (plist-get (sifox/tc-db-get x) :parents))))))
    out))

(defun sifox/tc-graph-problems ()
  "List of strings describing what is wrong with the graph; nil if nothing."
  (let (out)
    (dolist (c (sifox/tc-db-cases))
      (let ((id (plist-get c :id)))
        (dolist (p (plist-get c :parents))
          (unless (sifox/tc-db-get p)
            (push (format "%s: родителя %s нет в данных" id p) out)))
        (unless (assq (plist-get c :access) sifox/tc-access)
          (push (format "%s: :access должен быть r, w или x, а не %S" id (plist-get c :access)) out))
        (unless (plist-get c :steps)
          (push (format "%s: нет шагов" id) out))
        (cl-loop for s in (plist-get c :steps) for n from 1
                 when (string-empty-p (or (plist-get s :then) ""))
                 do (push (format "%s: шаг %d без Then" id n) out))
        (when (> (length (plist-get c :actual)) (length (plist-get c :steps)))
          (push (format "%s: в :actual больше пунктов, чем шагов" id) out))
        (when (and (not (sifox/tc-setup-p c))
                   (not (assoc (plist-get c :priority) sifox/tc-priorities)))
          (push (format "%s: приоритет %S не из `sifox/tc-priorities'" id (plist-get c :priority)) out))
        ;; a module starts with the least privilege
        (when (and (not (sifox/tc-setup-p c))
                   (not (eq (plist-get c :access) 'r))
                   (not (cl-some (lambda (p) (equal (plist-get (sifox/tc-db-get p) :module)
                                                    (plist-get c :module)))
                                 (plist-get c :parents))))
          (push (format "%s: корень модуля «%s» уровня %s, а должен быть r"
                        id (plist-get c :module) (plist-get c :access))
                out))))
    (dolist (id (sifox/tc--cycle-members))
      (push (format "%s: цикл - кейс является собственным предком" id) out))
    (nreverse out)))

(defun sifox/tc-validate ()
  "Show the problems of the graph, if any."
  (interactive)
  (let ((problems (sifox/tc-graph-problems)))
    (if (null problems)
        (message "Граф в порядке: %d кейсов, корней %d"
                 (length (sifox/tc-db-cases)) (length (sifox/tc-roots)))
      (with-current-buffer (get-buffer-create "*sifox-tc-validate*")
        (erase-buffer)
        (insert (string-join problems "\n") "\n")
        (display-buffer (current-buffer)))
      (message "Проблем в графе: %d" (length problems)))
    problems))

;;; ---- rendering

(defun sifox/tc-org-keyword (status)
  (or (cdr (assoc status sifox/tc-statuses)) (cdar sifox/tc-statuses)))

(defun sifox/tc-status-of-keyword (kw)
  (car (rassoc kw sifox/tc-statuses)))

(defun sifox/tc-heading-text (c)
  (concat (plist-get c :id) ": " (plist-get c :title)))

(defun sifox/tc-tags (c)
  (append (list (symbol-name (plist-get c :access)))
          (when (sifox/tc-setup-p c) (list sifox/tc-setup-tag))))

(defun sifox/tc--step-lines (step)
  "Lines of STEP: Given / When / Then, the missing ones left out."
  (cl-loop for (key label) in '((:given "Given") (:when "When") (:then "Then"))
           for text = (plist-get step key)
           unless (string-empty-p (or text ""))
           collect (format "*%s* %s" label text)))

(defun sifox/tc--item (n box lines)
  "Org list item N with checkbox BOX and LINES (the rest are indented)."
  (let* ((bullet (format "%d. " n))
         (indent (make-string (length bullet) ?\s)))
    (concat bullet "[" box "]"
            (if lines (concat " " (mapconcat #'identity lines (concat "\n" indent))) "")
            "\n")))

(defun sifox/tc-render-expected (c)
  (let ((actual (sifox/tc-normalize-actual c)))
    (cl-loop for s in (plist-get c :steps) for a in actual for n from 1
             concat (sifox/tc--item n (if (eq (plist-get a :state) 'todo) " " "X")
                                    (sifox/tc--step-lines s)))))

(defun sifox/tc-render-actual (c)
  (cl-loop for a in (sifox/tc-normalize-actual c) for n from 1
           concat (sifox/tc--item n (pcase (plist-get a :state) ('ok "X") ('fail "-") (_ " "))
                                  (unless (string-empty-p (plist-get a :note))
                                    (split-string (plist-get a :note) "\n")))))

(defun sifox/tc--cookie (c)
  (let ((actual (sifox/tc-normalize-actual c)))
    (format "[%d/%d]"
            (cl-count 'ok actual :key (lambda (a) (plist-get a :state)))
            (length actual))))

(defun sifox/tc--section (level title text)
  (let ((text (or text "")))
    (concat (make-string level ?*) " " title "\n"
            (cond ((string-empty-p text) "")
                  ((string-suffix-p "\n" text) text)
                  (t (concat text "\n")))
            "\n")))

(defun sifox/tc--parent-links (c)
  "Line «После: …» with a link and the title for every parent, or nil."
  (when (plist-get c :parents)
    (concat "После: "
            (mapconcat (lambda (p)
                         (let ((pc (sifox/tc-db-get p)))
                           (format "[[#%s][%s]]%s" p p
                                   (if pc (concat " " (plist-get pc :title)) ""))))
                       (plist-get c :parents) "; ")
            "\n")))

(defun sifox/tc-render (c level)
  "Org entry for case C at heading LEVEL, without its child cases."
  (let ((prio (cdr (assoc (plist-get c :priority) sifox/tc-priorities)))
        (sub (1+ level)))
    (concat (make-string level ?*) " " (sifox/tc-org-keyword (plist-get c :status)) " "
            (if prio (format "[#%c] " prio) "")
            (sifox/tc-heading-text c)
            " :" (string-join (sifox/tc-tags c) ":") ":\n"
            ":PROPERTIES:\n"
            ":CASE_ID: " (plist-get c :id) "\n"
            ":CUSTOM_ID: " (plist-get c :id) "\n"
            ":ACCESS: " (symbol-name (plist-get c :access)) "\n"
            (if (plist-get c :severity) (concat ":SEVERITY: " (plist-get c :severity) "\n") "")
            (if (plist-get c :roles)
                (concat ":ROLES: " (string-join (plist-get c :roles) ", ") "\n") "")
            (if (plist-get c :parents)
                (concat ":PARENTS: " (string-join (plist-get c :parents) " ") "\n") "")
            ":END:\n"
            (or (sifox/tc--parent-links c) "")
            "\n"
            (sifox/tc--section sub sifox/tc--expected-title (sifox/tc-render-expected c))
            (sifox/tc--section sub (concat sifox/tc--actual-title " " (sifox/tc--cookie c))
                               (sifox/tc-render-actual c))
            (sifox/tc--section sub sifox/tc--comment-title (plist-get c :comment)))))

;;; ---- headings in the current org buffer

(defun sifox/tc--todo-line ()
  (concat "#+TODO: " (cdar sifox/tc-statuses) " | "
          (mapconcat #'cdr (cdr sifox/tc-statuses) " ")))

(defun sifox/tc--ensure-todo-keywords ()
  "Declare the keywords of `sifox/tc-statuses' in the buffer if some are missing.
Return non-nil when a #+TODO line was added."
  (unless (cl-every (lambda (s) (member (cdr s) org-todo-keywords-1)) sifox/tc-statuses)
    (save-excursion
      (goto-char (point-min))
      (while (looking-at-p "^#\\+") (forward-line 1))
      (insert (sifox/tc--todo-line) "\n"))
    (org-mode-restart)
    t))

(defun sifox/tc--case-pos (id)
  "Position of the heading of case ID in the buffer, or nil."
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (point-min))
      (when (re-search-forward (format "^[ \t]*:CASE_ID:[ \t]*%s[ \t]*$" (regexp-quote id)) nil t)
        (org-back-to-heading t)
        (point)))))

(defun sifox/tc--subtree-end (pos)
  "End of the subtree whose heading is at POS; end of buffer when POS is nil."
  (if pos
      (save-excursion (goto-char pos) (org-end-of-subtree t t) (point))
    (point-max)))

(defun sifox/tc--find-child (parent level title)
  "Position of the heading TITLE at LEVEL inside PARENT's subtree (or buffer)."
  (save-excursion
    (goto-char (or parent (point-min)))
    (let ((end (sifox/tc--subtree-end parent))
          (re (format "^\\*\\{%d\\}[ \t]+%s[ \t]*$" level (regexp-quote title)))
          found)
      (when parent (forward-line 1))
      (while (and (not found) (re-search-forward re end t))
        (setq found (line-beginning-position)))
      found)))

(defun sifox/tc--insert-at (pos text)
  "Insert TEXT at POS on a line of its own."
  (save-excursion
    (goto-char pos)
    (unless (bolp) (insert "\n"))
    (insert text)))

(defun sifox/tc--read-module ()
  (let ((mods (delete-dups (mapcar (lambda (c) (plist-get c :module)) (sifox/tc-db-cases)))))
    (unless mods (user-error "В %s нет тест-кейсов" (expand-file-name sifox/tc-db-file)))
    (completing-read "Модуль: " mods nil t)))

(defun sifox/tc--cases-of (module)
  (if module (sifox/tc-db-find (lambda (c) (equal (plist-get c :module) module)))
    (sifox/tc-db-cases)))

(defun sifox/tc--nest-parent (c)
  "Id of the first parent of C if it is in the same module, else nil."
  (let* ((p (car (plist-get c :parents))) (pc (and p (sifox/tc-db-get p))))
    (and pc (equal (plist-get pc :module) (plist-get c :module)) p)))

(defun sifox/tc--insert-order (cases)
  "CASES ordered so that a nesting parent comes before its children."
  (let ((ids (mapcar (lambda (c) (plist-get c :id)) cases))
        (done (make-hash-table :test #'equal)) out)
    (cl-labels ((visit (c stack)
                  (let ((id (plist-get c :id)))
                    (unless (or (gethash id done) (member id stack))
                      (let ((p (sifox/tc--nest-parent c)))
                        (when (and p (member p ids))
                          (visit (sifox/tc-db-get p) (cons id stack))))
                      (puthash id t done)
                      (push c out)))))
      (dolist (c cases) (visit c nil)))
    (nreverse out)))

(defun sifox/tc-insert-cases (&optional module)
  "Insert the cases of `sifox/tc-db-file' under the heading at point.
MODULE (with \\[universal-argument], asked) limits them to one module.
A heading per module; a case is nested in its first parent when that parent
is in the same module and in the buffer, else it goes to the module heading.
Cases already in the buffer (by CASE_ID) are skipped.
Return the number of inserted cases."
  (interactive (list (when current-prefix-arg (sifox/tc--read-module))))
  (unless (derived-mode-p 'org-mode) (user-error "Нужен org-буфер"))
  (let ((cases (sifox/tc--cases-of module)) (inserted 0))
    (unless cases
      (user-error "В %s нет тест-кейсов%s" (expand-file-name sifox/tc-db-file)
                  (if module (format " модуля «%s»" module) "")))
    (let* ((new (seq-remove (lambda (c) (sifox/tc--case-pos (plist-get c :id))) cases))
           (parent (unless (org-before-first-heading-p)
                     (save-excursion (org-back-to-heading t) (point-marker))))
           (base (if parent (save-excursion (goto-char parent) (org-current-level)) 0)))
      (when new
        (when (sifox/tc--ensure-todo-keywords)
          (message "Добавлена строка %s" (sifox/tc--todo-line)))
        (dolist (c (sifox/tc--insert-order new))
          (let* ((np (sifox/tc--nest-parent c))
                 (np-pos (and np (sifox/tc--case-pos np))))
            (if np-pos
                (sifox/tc--insert-at (sifox/tc--subtree-end np-pos)
                                     (sifox/tc-render
                                      c (1+ (save-excursion (goto-char np-pos) (org-current-level)))))
              (let* ((title (plist-get c :module))
                     (head (or (sifox/tc--find-child parent (1+ base) title)
                               (progn
                                 (sifox/tc--insert-at (sifox/tc--subtree-end parent)
                                                      (concat (make-string (1+ base) ?*) " " title "\n"))
                                 (sifox/tc--find-child parent (1+ base) title)))))
                (sifox/tc--insert-at (sifox/tc--subtree-end head)
                                     (sifox/tc-render c (+ base 2)))))
            (cl-incf inserted)))
        (org-align-tags t)))
    (message "Тест-кейсы: вставлено %d, уже были в буфере %d" inserted (- (length cases) inserted))
    inserted))

;;; ---- the case at point

(defun sifox/tc-goto-case-heading ()
  "Move to the nearest heading at or above point with CASE_ID; return the id."
  (org-back-to-heading t)
  (let (id)
    (while (and (not (setq id (org-entry-get nil "CASE_ID")))
                (org-up-heading-safe)))
    (or id (user-error "Выше точки нет заголовка с CASE_ID"))))

(defun sifox/tc--section-bounds (title)
  "(BEG . END) of the text under the section TITLE of the case at point, or nil.
Only the case's own section (one level below it) is looked at; a statistics
cookie after TITLE is allowed."
  (save-excursion
    (sifox/tc-goto-case-heading)
    (let* ((level (org-current-level))
           (end (save-excursion (org-end-of-subtree t t) (point)))
           (re (format "^\\*\\{%d\\}[ \t]+%s\\(?:[ \t]+\\[[0-9/%%]*\\]\\)?[ \t]*$"
                       (1+ level) (regexp-quote title))))
      (when (re-search-forward re end t)
        (forward-line 1)
        (cons (point) (min end (save-excursion
                                 (if (re-search-forward "^\\*+ " end t)
                                     (line-beginning-position)
                                   end))))))))

(defun sifox/tc--section-text (title)
  (let ((b (sifox/tc--section-bounds title)))
    (when b (string-trim (buffer-substring-no-properties (car b) (cdr b))))))

(defun sifox/tc-parse-actual (text)
  "Parse the list under «Фактическое поведение»: alist (N . (:state S :note TEXT)).
[X] is ok; [-], or [ ] with a text, is a deviation; an empty [ ] is not checked."
  (let (items cur)
    (dolist (line (split-string (or text "") "\n"))
      (cond ((string-match "\\`[ \t]*\\([0-9]+\\)[.)][ \t]+\\[\\([ Xx-]\\)\\][ \t]*\\(.*\\)\\'" line)
             (setq cur (list (string-to-number (match-string 1 line))
                             (match-string 2 line)
                             (list (match-string 3 line))))
             (push cur items))
            (cur (setf (nth 2 cur) (append (nth 2 cur) (list (string-trim line)))))))
    (mapcar (lambda (it)
              (let ((note (string-trim (string-join (nth 2 it) "\n"))))
                (cons (car it)
                      (list :state (cond ((member (nth 1 it) '("X" "x")) 'ok)
                                         ((equal (nth 1 it) "-") 'fail)
                                         ((string-empty-p note) 'todo)
                                         (t 'fail))
                            :note note))))
            (nreverse items))))

(defun sifox/tc-read-entry (c)
  "Run results of case C from the entry at point: plist :actual :comment :keyword."
  (save-excursion
    (sifox/tc-goto-case-heading)
    (let ((parsed (sifox/tc-parse-actual (sifox/tc--section-text sifox/tc--actual-title))))
      (list :actual (cl-loop for _ in (plist-get c :steps) for n from 1
                             collect (or (cdr (assq n parsed)) (list :state 'todo :note "")))
            :comment (or (sifox/tc--section-text sifox/tc--comment-title) "")
            :keyword (org-get-todo-state)))))

(defun sifox/tc--set-keyword (kw)
  "Set the TODO keyword of the case at point to KW without running the hooks."
  (save-excursion
    (sifox/tc-goto-case-heading)
    (unless (equal (org-get-todo-state) kw)
      (let ((org-after-todo-state-change-hook nil) (org-log-done nil)
            (org-todo-log-states nil) (org-inhibit-logging t))
        (org-todo kw)))))

(defun sifox/tc-sync ()
  "Copy the checkboxes, notes and comment of the case at point to the database.
The status is derived (see `sifox/tc-derive-status') and the heading keyword
is set to match it."
  (interactive)
  (let* ((id (save-excursion (sifox/tc-goto-case-heading)))
         (old (or (sifox/tc-db-get id)
                  (user-error "Кейса %s нет в %s" id (expand-file-name sifox/tc-db-file))))
         (entry (sifox/tc-read-entry old))
         (actual (plist-get entry :actual))
         (status (sifox/tc-derive-status
                  actual (sifox/tc-status-of-keyword (plist-get entry :keyword))))
         (new (sifox/rp-merge old (list :actual actual :status status
                                        :comment (plist-get entry :comment))))
         (diff (sifox/rp-diff (plist-put (copy-sequence old) :actual (sifox/tc-normalize-actual old))
                              new '(:status :actual :comment))))
    (when diff
      (setq new (plist-put new :history (append (plist-get old :history) diff)))
      (setq new (plist-put new :updated (sifox/rp-now)))
      (sifox/tc-db-put new))
    (sifox/tc--set-keyword (sifox/tc-org-keyword status))
    (message "%s: %s%s%s" id status
             (if diff "" " (без изменений)")
             (let ((b (sifox/tc-blocked-by id)))
               (if b (format "; выше по графу не пройдены: %s" (string-join b ", ")) "")))
    new))

(defun sifox/tc--tick-all ()
  "Mark every item of «Фактическое поведение» of the case at point as [X]."
  (let ((b (sifox/tc--section-bounds sifox/tc--actual-title)))
    (when b
      (save-excursion
        (goto-char (car b))
        (let ((end (copy-marker (cdr b))))
          (while (re-search-forward "^[ \t]*[0-9]+[.)][ \t]+\\[\\([ -]\\)\\]" end t)
            (replace-match "X" t t nil 1))
          (goto-char (car b))
          (ignore-errors (org-update-checkbox-count)))))))

(defun sifox/tc--case-section-p ()
  "Non-nil if the heading at point is a section (not a case or a report) of a case."
  (and (not (org-entry-get nil "CASE_ID"))
       (not (org-entry-get nil "REPORT_ID"))
       (save-excursion (and (org-up-heading-safe) (org-entry-get nil "CASE_ID")))))

(defun sifox/tc-on-todo-change ()
  "For `org-after-todo-state-change-hook': sync a case when its state changes.
PASS set by hand ticks every item of «Фактическое поведение».  A state set
on a section of the case is moved to the case heading."
  (when (derived-mode-p 'org-mode)
    (cond ((org-entry-get nil "CASE_ID")
           (when (equal org-state (sifox/tc-org-keyword "Пройден"))
             (sifox/tc--tick-all))
           (sifox/tc-sync))
          ((and org-state (sifox/tc--case-section-p))
           (let ((state org-state))
             (org-todo 'none)
             (save-excursion (org-up-heading-safe) (org-todo state)))))))

;;; ---- a new child case

(defun sifox/tc-next-id (parent-id &optional setup)
  "Next free id with the prefix of PARENT-ID: PFX-NNN, or PFX-SNN for SETUP."
  (let* ((prefix (replace-regexp-in-string "-S?[0-9]+\\'" "" parent-id))
         (re (format "\\`%s-%s\\([0-9]+\\)\\'" (regexp-quote prefix) (if setup "S" "")))
         (max (apply #'max 0 (cl-loop for c in (sifox/tc-db-cases)
                                      when (string-match re (plist-get c :id))
                                      collect (string-to-number (match-string 1 (plist-get c :id)))))))
    (format (if setup "%s-S%02d" "%s-%03d") prefix (1+ max))))

(defun sifox/tc-read-access (&optional cur)
  (let* ((names (mapcar (lambda (a) (format "%s %s" (car a) (cdr a))) sifox/tc-access))
         (def (seq-find (lambda (n) (string-prefix-p (symbol-name (or cur 'r)) n)) names)))
    (intern (car (split-string (completing-read "Уровень операции: " names nil t nil nil def))))))

(defun sifox/tc-read-step (n)
  "Read step N: Given and When may be empty; an empty Then ends the steps."
  (let* ((given (read-string (format "Шаг %d. Given (можно пусто): " n)))
         (when (read-string (format "Шаг %d. When (пусто - ещё одна проверка): " n)))
         (then (read-string (format "Шаг %d. Then (пусто - шагов больше нет): " n))))
    (unless (string-empty-p then)
      (append (unless (string-empty-p given) (list :given given))
              (unless (string-empty-p when) (list :when when))
              (list :then then)))))

(defun sifox/tc-read-steps ()
  (let (steps step)
    (while (setq step (sifox/tc-read-step (1+ (length steps))))
      (setq steps (append steps (list step))))
    (or steps (user-error "Нужен хотя бы один шаг с Then"))))

(defun sifox/tc-new-child (&optional setup)
  "Create a child of the case at point: ask its fields, save it, insert it.
The new case gets the next free id of the parent's module, the parent's
module and roles, and the case at point as its first parent.  It is written
to `sifox/tc-db-file' and inserted as the last child of the parent heading.
With \\[universal-argument] (SETUP) the child is a manual setup case.
Return the new case."
  (interactive "P")
  (unless (derived-mode-p 'org-mode) (user-error "Нужен org-буфер"))
  (let* ((pid (save-excursion (sifox/tc-goto-case-heading)))
         (parent (or (sifox/tc-db-get pid)
                     (user-error "Кейса %s нет в %s" pid (expand-file-name sifox/tc-db-file))))
         (id (sifox/tc-next-id pid setup))
         (title (let ((s (read-string (format "%s, ребёнок %s. Название: " id pid))))
                  (if (string-empty-p s) (user-error "Название обязательно") s)))
         (access (sifox/tc-read-access (plist-get parent :access)))
         (priority (unless setup
                     (completing-read "Приоритет: " (mapcar #'car sifox/tc-priorities) nil t nil nil
                                      (or (plist-get parent :priority) (caar sifox/tc-priorities)))))
         (severity (unless setup (sifox/rp-read-severity (plist-get parent :severity))))
         (more (delete pid (completing-read-multiple
                            "Другие родители (пусто - нет): "
                            (mapcar (lambda (c) (plist-get c :id)) (sifox/tc-db-cases)))))
         (steps (sifox/tc-read-steps))
         (c (sifox/tc-new-case
             (append (list :id id :module (plist-get parent :module) :title title :access access)
                     (when setup (list :setup t))
                     (list :roles (plist-get parent :roles) :parents (cons pid more))
                     (unless setup (list :priority priority :severity severity))
                     (list :steps steps)))))
    (sifox/tc-db-put c)
    (let ((problems (seq-filter (lambda (p) (string-prefix-p (concat id ":") p))
                                (sifox/tc-graph-problems))))
      (when problems (message "Внимание: %s" (string-join problems "; "))))
    (sifox/tc-goto-case-heading)
    (let ((level (org-current-level))
          (end (save-excursion (org-end-of-subtree t t) (point))))
      (sifox/tc--insert-at end (sifox/tc-render c (1+ level)))
      (org-align-tags t)
      (goto-char (sifox/tc--case-pos id)))
    (message "%s создан под %s и записан в %s" id pid (file-name-nondirectory sifox/tc-db-file))
    c))

;;; ---- progress

(defun sifox/tc--progress-of (cases)
  "Progress plist of CASES; setup cases are not counted."
  (let* ((cases (seq-remove #'sifox/tc-setup-p cases))
         (initial (caar sifox/tc-statuses))
         (total (length cases))
         (done (cl-count-if (lambda (c) (not (equal (plist-get c :status) initial))) cases))
         (counts (mapcar (lambda (s) (cons (car s) 0)) sifox/tc-statuses)))
    (dolist (c cases)
      (let* ((st (plist-get c :status)) (cell (assoc st counts)))
        (if cell (cl-incf (cdr cell))
          (setq counts (append counts (list (cons st 1)))))))
    (list :total total :done done
          :percent (if (zerop total) 0.0 (/ (* 100.0 done) total))
          :by-status counts)))

(defun sifox/tc-progress (&optional module show)
  "Share of processed cases in `sifox/tc-db-file', by :status.
A case is processed when its status is not «Не запускался»; setup cases are
not counted.  MODULE limits the count to one module (interactively with
\\[universal-argument]).  Return (:total N :done N :percent P :by-status
((STATUS . N) …)).  With SHOW (always interactively) also show it."
  (interactive (list (when current-prefix-arg (sifox/tc--read-module)) t))
  (let ((r (sifox/tc--progress-of (sifox/tc--cases-of module))))
    (when show
      (message "%sРазобрано %d из %d (%.1f%%): %s"
               (if module (format "«%s». " module) "")
               (plist-get r :done) (plist-get r :total) (plist-get r :percent)
               (mapconcat (lambda (c) (format "%s %d" (car c) (cdr c)))
                          (seq-remove (lambda (c) (zerop (cdr c))) (plist-get r :by-status))
                          ", ")))
    r))

(defun sifox/tc-priority-progress (priority)
  "Like `sifox/tc-progress', for the cases whose :priority is PRIORITY (a string)."
  (sifox/tc--progress-of
   (sifox/tc-db-find (lambda (c) (equal (plist-get c :priority) priority)))))

;;; ---- JSON

(defun sifox/tc--json-list (list) (vconcat list))

(defun sifox/tc-graph ()
  "The graph as an alist for `json-encode': format, generated, nodes, edges, roots."
  (let ((cases (sifox/tc-db-cases)))
    `((format . 2)
      (generated . ,(sifox/rp-now))
      (nodes
       . ,(sifox/tc--json-list
           (mapcar
            (lambda (c)
              (let ((id (plist-get c :id)))
                `((id . ,id)
                  (module . ,(plist-get c :module))
                  (title . ,(plist-get c :title))
                  (access . ,(symbol-name (plist-get c :access)))
                  (setup . ,(if (sifox/tc-setup-p c) t :json-false))
                  (roles . ,(sifox/tc--json-list (plist-get c :roles)))
                  (priority . ,(and (plist-get c :priority)
                                    (string-to-number (plist-get c :priority))))
                  (effective_priority . ,(sifox/tc-effective-priority id))
                  (severity . ,(plist-get c :severity))
                  (status . ,(plist-get c :status))
                  (parents . ,(sifox/tc--json-list (plist-get c :parents)))
                  (children . ,(sifox/tc--json-list (sifox/tc-children id)))
                  (blocking . ,(if (sifox/tc-blocking-p c) t :json-false))
                  (blocked_by . ,(sifox/tc--json-list (sifox/tc-blocked-by id)))
                  (steps
                   . ,(sifox/tc--json-list
                       (cl-loop for s in (plist-get c :steps)
                                for a in (sifox/tc-normalize-actual c)
                                for n from 1
                                collect `((n . ,n)
                                          (given . ,(plist-get s :given))
                                          (when . ,(plist-get s :when))
                                          (then . ,(plist-get s :then))
                                          (gate . ,(if (sifox/tc-step-gate-p s) t :json-false))
                                          (state . ,(symbol-name (plist-get a :state)))
                                          (note . ,(plist-get a :note))))))
                  (comment . ,(or (plist-get c :comment) ""))
                  (reports . ,(sifox/tc--json-list (plist-get c :reports))))))
            cases)))
      (edges
       . ,(sifox/tc--json-list
           (cl-loop for c in cases
                    append (cl-loop for p in (plist-get c :parents) for first = t then nil
                                    collect `((from . ,p) (to . ,(plist-get c :id))
                                              (primary . ,(if first t :json-false)))))))
      (roots . ,(sifox/tc--json-list (sifox/tc-roots))))))

(defun sifox/tc-json-string ()
  (let ((json-encoding-pretty-print t)
        (json-null nil) (json-false :json-false))
    (concat (json-encode (sifox/tc-graph)) "\n")))

(defun sifox/tc-json-export (file)
  "Write the graph of cases to FILE as JSON."
  (interactive "FJSON графа: ")
  (let ((coding-system-for-write 'utf-8-unix))
    (with-temp-file file (insert (sifox/tc-json-string))))
  (message "Граф: %d узлов -> %s" (length (sifox/tc-db-cases)) file)
  file)

;;; ---- TSV (flat, for uat-progress.awk and other tools)

(defvar sifox/tc-tsv-columns
  '("ID" "Модуль" "Название" "Тип" "Доступ" "Родители" "Роли" "Приоритет" "Severity"
    "Статус" "Шаги" "Фактическое поведение" "Комментарий тестировщика")
  "Columns of `sifox/tc-tsv-export'.")

(defvar sifox/tc-tsv-newline " "
  "Replacement for a line break inside a cell on TSV export.
The TSV has no quoting, so a cell can hold neither a line break nor a tab.")

(defun sifox/tc--tsv-cell (s)
  (replace-regexp-in-string
   "\t" " " (replace-regexp-in-string "[ \t]*\r?\n[ \t]*" sifox/tc-tsv-newline (or s ""))))

(defun sifox/tc--steps-text (c)
  (cl-loop for s in (plist-get c :steps) for n from 1
           concat (format "%s%d. %s" (if (= n 1) "" " ") n
                          (replace-regexp-in-string
                           "\\*" "" (string-join (sifox/tc--step-lines s) " ")))))

(defun sifox/tc--actual-text (c)
  (cl-loop for a in (sifox/tc-normalize-actual c) for n from 1
           concat (format "%s%d. [%s]%s" (if (= n 1) "" " ") n (plist-get a :state)
                          (if (string-empty-p (plist-get a :note)) ""
                            (concat " " (plist-get a :note))))))

(defun sifox/tc-to-row (c)
  "TSV cells of case C, in `sifox/tc-tsv-columns' order."
  (mapcar (lambda (h)
            (pcase h
              ("ID" (plist-get c :id))
              ("Модуль" (plist-get c :module))
              ("Название" (plist-get c :title))
              ("Тип" (if (sifox/tc-setup-p c) "подготовка" "кейс"))
              ("Доступ" (symbol-name (plist-get c :access)))
              ("Родители" (string-join (plist-get c :parents) ", "))
              ("Роли" (string-join (plist-get c :roles) ", "))
              ("Приоритет" (or (plist-get c :priority) ""))
              ("Severity" (or (plist-get c :severity) ""))
              ("Статус" (plist-get c :status))
              ("Шаги" (sifox/tc--steps-text c))
              ("Фактическое поведение" (sifox/tc--actual-text c))
              ("Комментарий тестировщика" (or (plist-get c :comment) ""))
              (_ "")))
          sifox/tc-tsv-columns))

(defun sifox/tc-tsv-string (cases)
  "TSV text of CASES with CRLF line ends, header first."
  (mapconcat (lambda (cells) (concat (mapconcat #'sifox/tc--tsv-cell cells "\t") "\r\n"))
             (cons sifox/tc-tsv-columns (mapcar #'sifox/tc-to-row cases))
             ""))

(defun sifox/tc-tsv-export (file)
  "Write every case of the database to TSV FILE (flat; the graph is in «Родители»)."
  (interactive "FTSV: ")
  (let ((coding-system-for-write 'utf-8-unix))
    (with-temp-file file (insert (sifox/tc-tsv-string (sifox/tc-db-cases)))))
  file)

;;; ---- report from a case

(defun sifox/tc-report-draft (c)
  "Report fields prefilled from case C.
Steps to reproduce: the When lines along the chain of first parents, then the
case's own.  Expected / actual: the steps with a deviation (all steps when
there is none)."
  (let* ((id (plist-get c :id))
         (actual (sifox/tc-normalize-actual c))
         (failed (cl-loop for s in (plist-get c :steps) for a in actual for n from 1
                          when (eq (plist-get a :state) 'fail) collect (list n s a)))
         (shown (or failed
                    (cl-loop for s in (plist-get c :steps) for a in actual for n from 1
                             collect (list n s a))))
         (steps (cl-loop for pid in (sifox/tc-path id)
                         for pc = (if (equal pid id) c (sifox/tc-db-get pid))
                         append (cl-loop for s in (plist-get pc :steps)
                                         for w = (plist-get s :when)
                                         unless (string-empty-p (or w ""))
                                         collect (format "[%s] %s" pid w))))
         (given (let ((ps (plist-get c :parents)))
                  (if ps (concat "Выполнены: " (string-join ps ", ")) ""))))
    (list :title (plist-get c :title)
          :steps steps
          :expected (list :given given :when (plist-get c :title)
                          :then (mapconcat (lambda (x) (format "%d. %s" (car x) (plist-get (nth 1 x) :then)))
                                           shown "\n"))
          :actual (list :given given :when (plist-get c :title)
                        :then (mapconcat (lambda (x) (format "%d. %s" (car x) (plist-get (nth 2 x) :note)))
                                         shown "\n"))
          :severity (plist-get c :severity)
          :case id)))

(defun sifox/tc-report ()
  "Create a report from the case at point and insert it as the last child."
  (interactive)
  (unless (derived-mode-p 'org-mode) (user-error "Нужен org-буфер"))
  (let* ((id (save-excursion (sifox/tc-goto-case-heading)))
         (c (sifox/tc-sync))
         (draft (sifox/tc-report-draft c))
         (r (sifox/rp-read-fields (list :status (car (or org-todo-keywords-1 '("TODO")))
                                        :title (plist-get draft :title)
                                        :severity (plist-get draft :severity))
                                  (sifox/rp-create-keys)))
         (now (sifox/rp-now)))
    (setq r (plist-put r :code (sifox/rp-next-code (plist-get r :type) (plist-get r :area))))
    (setq r (append (list :id (org-id-uuid)) r
                    (list :tracker "" :steps (plist-get draft :steps)
                          :expected (plist-get draft :expected)
                          :actual (plist-get draft :actual)
                          :case id :file (sifox/rp-file)
                          :created now :updated now :history nil)))
    (sifox/rp-db-put r)
    (sifox/tc-db-put (plist-put (copy-sequence c) :reports
                                (append (plist-get c :reports) (list (plist-get r :id)))))
    (save-excursion
      (sifox/tc-goto-case-heading)
      (let ((level (org-current-level)))
        (org-end-of-subtree t t)
        (unless (bolp) (insert "\n"))
        (insert (sifox/rp-render r (1+ level)))
        (forward-line -1)
        (sifox/rp-align-entry-table)))
    (message "%s создан из %s" (plist-get r :code) id)
    r))

(provide 'sifox-case)
;;; sifox-case.el ends here
