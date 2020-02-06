;;; eglot-flycheck-adaptor.el --- Use flycheck instead of flymake for eglot diagnostics  -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Akash Hiremath

;; Author: Akash Hiremath <akashh246@gmail.com>
;; Keywords: tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Use flycheck instead of flymake for eglot diagnostics

;;; Code:

(require 'eglot)
(require 'flycheck)
(require 'flymake)
(require 'cl)

(defvar-local eglot-flycheck--fc-callback nil)

(cl-defun eglot-flycheck--point->line-col (buffer beg)
  (with-current-buffer buffer
    (save-excursion
      (goto-char beg)
      (cons (line-number-at-pos)
            (- (point)
               (line-beginning-position))))))

(cl-defun eglot-flycheck--fm-error->fc-error (err)
  (pcase-let* ((msg (flymake--diag-text err))
               (beg (flymake--diag-beg err))
               (buffer (flymake--diag-buffer err))
               (`(,line . ,col) (eglot-flycheck--point->line-col buffer beg)))
    (flycheck-error-new-at
     line nil ;; TODO: use column and region
     (pcase (flymake--diag-type err)
       ('eglot-error 'error)
       ('eglot-warning 'warning)
       ('eglot-note 'info))
     msg
     :checker 'eglot
     :buffer buffer
     :filename (buffer-file-name buffer))))

(cl-defun eglot-flycheck--flymake-handle-result (flymake-errors &key region)
  (let ((result (mapcar #'eglot-flycheck--fm-error->fc-error flymake-errors)))
    (flycheck-buffer)
    (funcall eglot-flycheck--fc-callback 'finished result)))

(cl-defun eglot-flycheck-checker (checker callback)
  (setq eglot-flycheck--fc-callback callback)
  (eglot-flymake-backend #'eglot-flycheck--flymake-handle-result))

(flycheck-define-generic-checker
    'eglot-checker
  "eglot flycheck checker"
  :start #'eglot-flycheck-checker
  :modes (eglot--all-major-modes))

(add-to-list 'flycheck-checkers 'eglot-checker)

(defadvice flymake-mode (around flymake-mode-around)
  "Always disable flymake-mode in eglot--managed-mode"
  (if (bound-and-true-p eglot--managed-mode)
      (ad-set-arg 0 0))
  ad-do-it)

(ad-activate 'flymake-mode)
