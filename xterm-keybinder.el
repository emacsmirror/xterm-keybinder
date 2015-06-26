;;; xterm-keybinder.el --- Let your terminal emacs to control keybinds in xterm -*- lexical-binding: t; -*-

;; Copyright (C) 2015  Yuta Yamada

;; Author: Yuta Yamada <sleepboy.zzz@gmail.com>
;; Package-Requires: ((emacs "24.3") (cl-lib "0.5"))
;; Version: 0.1.0
;; Keywords: Convenient

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
;; This package let your terminal Emacs C-[;:',.0-9]-keys,
;; C-S-[a-z]-keys, C-M-[a-z]-keys and C-M-S-[a-z]-keys on xterm.
;;
;; Usage:
;; Put below configuration to your .emacs
;;
;; -- configuration --
;;   (when (getenv "XTERM_VERSION")
;;     (add-hook 'terminal-init-xterm-hook 'xterm-keybinder-setup))
;; -- configuration end --
;;
;; Then start your emacs with xterm and the option.
;;
;; -- shell script example --
;;   #!/bin/sh
;;   xtermopt=path/to/this-repository/xterm-option
;;   eval "xterm -xrm `${xtermopt}` -e emacsclient -t -a ''"
;; -- shell script example end --
;;
;; See also: https://github.com/yuutayamada/xterm-keybinder-el/blob/master/README.md
;;; Code:

(require 'cl-lib)

(defconst xterm-keybinder-CSI "\033[") ; this means M-[ or ESC [
;; Use private key sequence of CSI
;; Private keys: #x3c, #x3d, #x3e, or #x3f.
;; See also: http://www.ecma-international.org/publications/files/ECMA-ST/Ecma-048.pdf page 26
;; Is there other document? I seem 1998 is too old...
(defconst xterm-keybinder-private-char #x3d)
(defconst xterm-keybinder-prefix
  (concat xterm-keybinder-CSI (format "%c" xterm-keybinder-private-char)))
(defconst xterm-keybinder-format
  (concat "  %s <KeyPress> %s: string(\"\\033["
          (format "%c" xterm-keybinder-private-char)
          "%s\") %s \\n\\"))
(defconst xterm-keybinder-C-char-list
  '(":" ";" "," "." "'" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9"))

;;;###autoload
(defun xterm-keybinder-setup ()
  "Enable Emacs keybinds even in the xterm terminal Emacs."
  (interactive)
  (let ((prefix xterm-keybinder-prefix)
        (map input-decode-map))
    ;; C-[0-9;:',.]
    (cl-loop for c in xterm-keybinder-C-char-list
             for def = (kbd (concat "C-" c))
             do (define-key map (concat prefix c) def))
    ;; C-S-[a-z], C-M-[a-z] and C-M-S-[a-z]
    (cl-loop for c from ?a to ?z
             for char = (char-to-string c)
             for C-S-key   = (kbd (concat "C-S-"   char))
             for C-M-key   = (kbd (concat "C-M-"   char))
             for C-M-S-key = (kbd (concat "C-M-S-" char))
             do (define-key map (concat prefix (capitalize char)) C-S-key)
             do (define-key map (concat prefix char) C-M-key)
             do (define-key map (concat prefix "=" char) C-M-S-key))
    ;; Treat irregular keybinds
    (define-key map (concat prefix " ") (kbd "S-SPC"))))

(defun xterm-keybinder-insert ()
  "Insert configuration for XTerm.
You can use this to insert xterm configuration by yourself."
  (interactive)
  (insert "\nXTerm.VT100.translations: #override \\n\\\n")
  (cl-loop for char in xterm-keybinder-C-char-list
           if (pcase char
                (`"." "period")
                (`"," "comma")
                (`":" "colon")
                (`";" "semicolon")
                ;; xrdb occur warning if it uses "'" as xresource
                ;; configuration, so this conversion has to do.
                (`"'" "apostrophe"))
           collect (xterm-keybinder-make-format 'C it "" char) into C-keys
           else collect (xterm-keybinder-make-format 'C char char) into C-keys
           finally (insert (concat (mapconcat 'identity C-keys "\n") "\n")))
  (cl-loop for c from ?a to ?z
           for char = (char-to-string c)
           collect (xterm-keybinder-make-format 'C-S char (capitalize char)) into cs
           collect (xterm-keybinder-make-format 'C-M char char) into cm
           collect (xterm-keybinder-make-format 'C-M-S char (concat "=" char)) into cms
           finally (insert (concat (mapconcat 'identity (append cs cm cms) "\n") "\n")))
  (let ((s (xterm-keybinder-make-format 'S "space" " ")))
    ;; Omit \n\ on the last
    (insert (substring s 0 (- (length s) 4)))))

(defun xterm-keybinder-convert (str)
  "Convert STR to list of Hex expression for xterm configuration."
  (cl-loop for c in (delq "" (split-string str ""))
           for char = (string-to-char c)
           collect (format "string(0x%x)" char) into chars
           finally return (mapconcat 'identity chars "")))

(defun xterm-keybinder-make-format (prefix c1 c2 &optional c3)
  "Make adapt format string from PREFIX, C1, and C2."
  (let ((p (cl-case prefix
             (C     "Ctrl ~Shift ~Alt ~Super ~Hyper")
             (S     "Shift ~Ctrl ~Alt ~Super ~Hyper")
             (C-S   "Ctrl Shift  ~Alt ~Super ~Hyper")
             (C-M   "Ctrl Alt ~Shift  ~Super ~Hyper")
             (C-M-S "Ctrl Alt  Shift  ~Super ~Hyper")))
        (s (if c3 (xterm-keybinder-convert c3) "")))
    (format xterm-keybinder-format p c1 c2 s)))

(provide 'xterm-keybinder)
;;; xterm-keybinder.el ends here
