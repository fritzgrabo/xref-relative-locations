;;; xref-relative-locations.el --- Relative location filenames in Xref buffers -*- lexical-binding: t; -*-

;; Copyright (C) 2020-2021 Fritz Grabo

;; Author: Fritz Grabo <me@fritzgrabo.com>
;; URL: https://github.com/fritzgrabo/xref-relative-locations
;; Version: 0.1
;; Package-Requires: ((emacs "25.1"))
;; Keywords: convenience, tools

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3 of the License, or (at
;; your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; If not, see http://www.gnu.org/licenses.

;;; Commentary:

;; This package provides a global minor mode to make location filenames
;; relative in Xref buffers.

;; This can be useful if your source of Xref locations in a project
;; (tags tables, shell commands, etc.) provides absolute location
;; filenames only, and your project lives in a somewhat deeply nested
;; directory structure: by hiding the base directory part of filenames,
;; the remaining relative part becomes succinct and more meaningful
;; in your current context.

;; Use the `xref-relative-locations-mode` command to toggle the minor
;; mode on or off globally.

;; Note that pre-existing Xref buffers are not affected by toggling the
;; minor mode on or off.

;; Also note that the Xref buffer content does not actually change as
;; other functionality might rely on absolute paths: rather, the base
;; directory part in location filenames is hidden using text overlays.

;;; Code:

(require 'subr-x)
(require 'vc)
(require 'xref)

(defvar xref-relative-locations-find-base-dir-function #'vc-root-dir
  "The function to use to find the current base directory.
Called without parameters in the context of the buffer that
issued the Xref command to find definitions/references.")

(defvar-local xref-relative-locations-base-dir nil
  "The base directory to use when making location filenames
  relative in the related Xref buffer.")

(defun xref-relative-locations--make-locations-relative (&rest)
  "Make location filenames relative in current Xref buffer."
  (when (derived-mode-p 'xref--xref-buffer-mode)
    (when-let* ((base-dir xref-relative-locations-base-dir)
                (pattern (concat "^" (regexp-quote (expand-file-name base-dir)) "/?")))
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward pattern nil t)
          (overlay-put (make-overlay (match-beginning 0) (match-end 0)) 'invisible t))))))

(defun xref--show-xref-buffer--relative-locations (orig-fun &rest args)
  "Call ORIG-FUN with ARGS, make location filenames relative in resulting buffer."
  (let ((base-dir (funcall xref-relative-locations-find-base-dir-function))
        (xref-buffer (apply orig-fun args)))
    (when base-dir
      (with-current-buffer xref-buffer
        (setq-local xref-relative-locations-base-dir base-dir)
        (xref-relative-locations--make-locations-relative)))
    xref-buffer))

;;;###autoload
(define-minor-mode xref-relative-locations-mode
  "Make location filenames relative in Xref buffers."
  :group 'xref
  :global t
  (if xref-relative-locations-mode
      (advice-add #'xref--show-xref-buffer :around #'xref--show-xref-buffer--relative-locations)
    (advice-remove #'xref--show-xref-buffer #'xref--show-xref-buffer--relative-locations))
  (if (functionp #'xref-revert-buffer) ;; Introduced in Emacs 27.1
      (if xref-relative-locations-mode
          (advice-add #'xref-revert-buffer :after #'xref-relative-locations--make-locations-relative)
        (advice-remove #'xref-revert-buffer #'xref-relative-locations--make-locations-relative))))

(provide 'xref-relative-locations)
;;; xref-relative-locations.el ends here
