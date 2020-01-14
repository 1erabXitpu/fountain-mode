;;; fountain-mode.el --- Major mode for screenwriting in Fountain markup -*- lexical-binding: t; -*-

;; Copyright (c) 2014-2019 Free Software Foundation, Inc.
;; Copyright (c) 2019-2020 Paul W. Rankin

;; Author: Paul W. Rankin <code@paulwrankin.com>
;; Keywords: wp, text
;; Version: 3.0.0
;; Package-Requires: ((emacs "24.5"))
;; URL: https://fountain-mode.org
;; git: https://github.com/rnkn/fountain-mode

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; # Fountain Mode #

;; Fountain Mode is a scriptwriting program for GNU Emacs using the
;; Fountain plain text markup format.

;; For more information on the fountain markup format, visit
;; <https://fountain.io>.

;; Screenshot: <https://f002.backblazeb2.com/file/pwr-share/fountain-mode.png>

;; ## Features ##

;; - Support for Fountain 1.1 specification
;; - WYSIWYG auto-align elements (display only, does not modify file
;;   contents) specific to script format, e.g. screenplay, stageplay or
;;   user-defined format
;; - Navigation by section, scene, character name, or page
;; - 3 levels of syntax highlighting
;; - Integration with outline to fold/cycle visibility of sections and
;;   scenes
;; - Integration with imenu (sections, scene headings, notes)
;; - Intergration with auto-insert for title page metadata
;; - Traditional TAB auto-completion writing style
;; - Automatically add/remove character "(CONT'D)"
;; - Export to plain text, HTML, LaTeX, Final Draft (FDX), or Fountain
;; - Export to standalone document or snippet
;; - Emphasis (bold, italic, underlined text)
;; - Include external files with {{ include: FILENAME }}
;; - Optionally display scene numbers in the right margin
;; - Intelligent insertion of a page breaks
;; - Automatic loading for *.fountain files
;; - Include or omit a title page
;; - Toggle visibility of emphasis delimiters and syntax characters
;; - Everything is customizable

;; Check out the Nicholl Fellowship sample script exported from Fountain
;; Mode to the following formats:

;; - plain text: <https://f002.backblazeb2.com/file/pwr-share/Nicholl_Fellowship_sample.txt>
;; - HTML: <https://f002.backblazeb2.com/file/pwr-share/fountain-export.html>
;; - Final Draft: <https://f002.backblazeb2.com/file/pwr-share/fountain-export.fdx>
;; - LaTeX: <https://www.overleaf.com/project/54ed9180966959cb7fdbde8e>

;; Most common features are accessible from the menu. For a full list of
;; functions and key-bindings, type C-h m.

;; ## Requirements ##

;; - Emacs 24.5
;; - LaTeX packages for PDF export: geometry fontspec titling fancyhdr
;;   marginnote ulem xstring oberdiek

;; ## Installation ##

;; The latest stable release of Fountain Mode is available via
;; [MELPA-stable] and can be installed with:

;;     M-x package-install RET fountain-mode RET

;; Alternately, download the [latest release], move this file into your
;; load-path and add to your .emacs/init.el file:

;;     (require 'fountain-mode)

;; If you prefer the latest but perhaps unstable version, install via
;; [MELPA], or clone the repository into your load-path and require as
;; above:

;;     git clone https://github.com/rnkn/fountain-mode.git

;; Users of Debian >=10 or Ubuntu >=18.04 can install Fountain Mode with:

;;     sudo apt install elpa-fountain-mode

;; [melpa]: https://melpa.org/#/fountain-mode "MELPA"
;; [melpa-stable]: https://stable.melpa.org/#/fountain-mode "MELPA-stable"
;; [latest release]: https://github.com/rnkn/fountain-mode/releases/latest "Fountain Mode latest release"

;; ## History ##

;; See: <https://github.com/rnkn/fountain-mode/releases>

;; ## Bugs and Feature Requests ##

;; To report bugs either use <https://github.com/rnkn/fountain-mode/issues>
;; or send an email to <help@fountain-mode.org>.


;;; Code:

(eval-when-compile (require 'subr-x))

(eval-when-compile
  (require 'lisp-mnt)
  (defconst fountain-version
    (lm-version load-file-name)))

(defun fountain-version ()
  "Return `fountain-mode' version."
  (interactive)
  (message "Fountain Mode %s" fountain-version))

(defgroup fountain ()
  "Major mode for screenwriting in Fountain markup."
  :prefix "fountain-"
  :group 'text)


;;; Customization

(defun fountain--set-and-refresh-all-font-lock (symbol value)
  "Set SYMBOL to VALUE and refresh defaults.

Cycle buffers and call `font-lock-refresh-defaults' when
`fountain-mode' is active."
  (set-default symbol value)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'fountain-mode)
        (font-lock-refresh-defaults)))))

(defcustom fountain-mode-hook
  '(turn-on-visual-line-mode fountain-outline-hide-custom-level)
  "Mode hook for `fountain-mode', run after the mode is turned on."
  :group 'fountain
  :type 'hook
  :options '(turn-on-visual-line-mode
             fountain-outline-hide-custom-level
             fountain-completion-update
             turn-on-flyspell))

(define-obsolete-variable-alias 'fountain-script-format
  'fountain-default-script-format "3.0.0")
(defcustom fountain-default-script-format "screenplay"
  "Default script format.

Can be overridden in metadata with, e.g.

    format: teleplay"
  :group 'fountain
  :type 'string
  :safe 'string)

(define-obsolete-variable-alias 'fountain-add-continued-dialog
  'fountain-add-contd-dialog "3.0.0")
(defcustom fountain-add-contd-dialog
  t
  "\\<fountain-mode-map>If non-nil, \\[fountain-contd-dialog-refresh] will mark continued dialogue.

When non-nil, append `fountain-contd-dialog-string' to
successively speaking characters with `fountain-contd-dialog-refresh'.

When nil, remove `fountain-contd-dialog-string' with
`fountain-contd-dialog-refresh'."
  :group 'fountain
  :type 'boolean
  :safe 'booleanp)

(define-obsolete-variable-alias 'fountain-continued-dialog-string
  'fountain-contd-dialog-string "3.0.0")
(defcustom fountain-contd-dialog-string
  " (CONT'D)"
  "String to append to character name speaking in succession.
If `fountain-add-contd-dialog' is non-nil, append this string
to character when speaking in succession.

WARNING: if you change this variable then call
`fountain-contd-dialog-refresh', strings matching the
previous value will not be recognized. Before changing this
variable, first make sure to set `fountain-add-contd-dialog'
to nil and run `fountain-contd-dialog-refresh', then make the
changes desired."
  :group 'fountain
  :type 'string
  :safe 'stringp)

(defcustom fountain-more-dialog-string
  "(MORE)"
  "String to append to dialog when breaking across pages."
  :type 'string
  :safe 'stringp)

(defcustom fountain-hide-emphasis-delim
  nil
  "If non-nil, make emphasis delimiters invisible."
  :group 'fountain
  :type 'boolean
  :safe 'booleanp
  :set (lambda (symbol value)
         (set-default symbol value)
         (dolist (buffer (buffer-list))
           (with-current-buffer buffer
             (when (derived-mode-p 'fountain-mode)
               (if fountain-hide-emphasis-delim
                   (add-to-invisibility-spec 'fountain-emphasis-delim)
                 (remove-from-invisibility-spec 'fountain-emphasis-delim))
               (font-lock-refresh-defaults))))))

(defcustom fountain-hide-syntax-chars
  nil
  "If non-nil, make syntax characters invisible."
  :group 'fountain
  :type 'boolean
  :safe 'booleanp
  :set (lambda (symbol value)
         (set-default symbol value)
         (dolist (buffer (buffer-list))
           (with-current-buffer buffer
             (when (derived-mode-p 'fountain-mode)
               (if fountain-hide-syntax-chars
                   (add-to-invisibility-spec 'fountain-syntax-chars)
                 (remove-from-invisibility-spec 'fountain-syntax-chars))
               (font-lock-refresh-defaults))))))

;; FIXME: fountain-mode shouldn't be formatting time, better to farm
;; this to something builtin.
(defcustom fountain-time-format
  "%F"
  "Format of date and time used when inserting `{{time}}'.
See `format-time-string'."
  :group 'fountain
  :type 'string
  :safe 'stringp)

(defcustom fountain-note-template
  " {{time}} - {{fullname}}: "
  "\\<fountain-mode-map>Template for inserting notes with \\[fountain-insert-note].
To include an item in a template you must use the full {{KEY}}
syntax.

    {{title}}    Buffer name without extension
    {{time}}     Short date format (defined in option `fountain-time-format')
    {{fullname}} User full name (defined in option `user-full-name')
    {{nick}}     User first name (defined in option `user-login-name')
    {{email}}    User email (defined in option `user-mail-address')

The default {{time}} - {{fullname}}: will insert something like:

    [[ 2017-12-31 - Alan Smithee: ]]"
  :group 'fountain
  :type 'string
  :safe 'stringp)


;;; Aligning

(defgroup fountain-align ()
  "Options for element alignment.

For each Fountain element this group contains a variable that can
be an integer representing align column for that element for all
formats, or a list where each element takes the form:

    (FORMAT INT)

Where FORMAT is a string and INT is the align column for that
format.

To disable element alignment, see `fountain-align-element'."
  :prefix "fountain-align-"
  :group 'fountain)

(defcustom fountain-align-elements
  t
  "If non-nil, elements will be displayed auto-aligned.
This option does not affect file contents."
  :group 'fountain-align
  :type 'boolean
  :safe 'booleanp
  :set #'fountain--set-and-refresh-all-font-lock)

(defcustom fountain-align-section-heading
  '(("screenplay" 0)
    ("teleplay" 0)
    ("stageplay" 30))
  "Column integer to which section headings should be aligned.

This option does not affect file contents."
  :group 'fountain-align
  :type '(choice integer
                 (repeat (group (string :tag "Format") integer)))
  :set #'fountain--set-and-refresh-all-font-lock)

(defcustom fountain-align-scene-heading
  '(("screenplay" 0)
    ("teleplay" 0)
    ("stageplay" 30))
  "Column integer to which scene headings should be aligned.

This option does not affect file contents."
  :group 'fountain-align
  :type '(choice integer
                 (repeat (group (string :tag "Format") integer)))
  :set #'fountain--set-and-refresh-all-font-lock)

(defcustom fountain-align-synopsis
  '(("screenplay" 0)
    ("teleplay" 0)
    ("stageplay" 30))
  "Column integer to which synopses should be aligned.

This option does not affect file contents."
  :group 'fountain-align
  :type '(choice integer
                 (repeat (group (string :tag "Format") integer)))
  :set #'fountain--set-and-refresh-all-font-lock)

(defcustom fountain-align-action
  '(("screenplay" 0)
    ("teleplay" 0)
    ("stageplay" 20))
  "Column integer to which action should be aligned.

This option does not affect file contents."
  :group 'fountain-align
  :type '(choice integer
                 (repeat (group (string :tag "Format") integer)))
  :set #'fountain--set-and-refresh-all-font-lock)

(defcustom fountain-align-character
  '(("screenplay" 20)
    ("teleplay" 20)
    ("stageplay" 30))
  "Column integer to which characters names should be aligned.

This option does not affect file contents."
  :group 'fountain-align
  :type '(choice integer
                 (repeat (group (string :tag "Format") integer)))
  :set #'fountain--set-and-refresh-all-font-lock)

(defcustom fountain-align-dialog
  '(("screenplay" 10)
    ("teleplay" 10)
    ("stageplay" 0))
  "Column integer to which dialog should be aligned.

This option does not affect file contents."
  :group 'fountain-align
  :type '(choice integer
                 (repeat (group (string :tag "Format") integer)))
  :set #'fountain--set-and-refresh-all-font-lock)

(defcustom fountain-align-paren
  '(("screenplay" 15)
    ("teleplay" 15)
    ("stageplay" 20))
  "Column integer to which parentheticals should be aligned.

This option does not affect file contents."
  :group 'fountain-align
  :type '(choice integer
                 (repeat (group (string :tag "Format") integer)))
  :set #'fountain--set-and-refresh-all-font-lock)

(defcustom fountain-align-trans
  '(("screenplay" 45)
    ("teleplay" 45)
    ("stageplay" 30))
  "Column integer to which transitions should be aligned.

This option does not affect file contents."
  :group 'fountain-align
  :type '(choice integer
                 (repeat (group (string :tag "Format") integer)))
  :set #'fountain--set-and-refresh-all-font-lock)

(defcustom fountain-align-center
  '(("screenplay" 20)
    ("teleplay" 20)
    ("stageplay" 20))
  "Column integer to which centered text should be aligned.

This option does not affect file contents."
  :group 'fountain-align
  :type '(choice integer
                 (repeat (group (string :tag "Format") integer)))
  :set #'fountain--set-and-refresh-all-font-lock)


;;; Autoinsert

(require 'autoinsert)

(defvar fountain-metadata-skeleton
  '(nil
    "title: " (skeleton-read "Title: " (file-name-base (buffer-name))) | -7 "\n"
    "credit: " (skeleton-read "Credit: " "written by") | -9 "\n"
    "author: " (skeleton-read "Author: " user-full-name) | -9 "\n"
    "format: " (skeleton-read "Script format: " fountain-default-script-format) | -9 "\n"
    "source: " (skeleton-read "Source: ") | -9 "\n"
    "date: " (skeleton-read "Date: " (format-time-string fountain-time-format)) | -7 "\n"
    "contact:\n" ("Contact details, %s: " "    " str | -4 "\n") | -9))

(define-auto-insert '(fountain-mode . "Fountain metadata skeleton")
  fountain-metadata-skeleton)


;;; Regular Expressions

(defvar fountain-scene-heading-regexp
  nil
  "Regular expression for matching scene headings.

    Group 1: match leading . for forced scene heading
    Group 2: match whole scene heading without scene number
    Group 3: match INT/EXT
    Group 4: match location
    Group 5: match suffix separator
    Group 6: match suffix
    Group 7: match space between scene heading and scene number
    Group 8: match first # delimiter
    Group 9: match scene number
    Group 10: match last # delimiter

Contructed with `fountain-init-scene-heading-regexp'. Requires
`fountain-match-scene-heading' for preceding blank line.")

(defcustom fountain-scene-heading-suffix-sep
  " --? "
  "Regular expression separating scene heading location from suffix.

WARNING: If you change this any existing scene headings will no
longer be parsed correctly."
  :group 'fountain
  :type 'regexp
  :safe 'regexp
  :set #'fountain--set-and-refresh-all-font-lock)

(defcustom fountain-scene-heading-suffix-list
  '("DAY" "NIGHT" "CONTINUOUS" "LATER" "MOMENTS LATER")
  "List of scene heading suffixes (case insensitive).

These are only used for auto-completion. Any scene headings can
have whatever suffix you like.

Separated from scene heading locations with
`fountain-scene-heading-suffix-sep'."
  :group 'fountain
  :type '(repeat (string :tag "Suffix"))
  :set #'fountain--set-and-refresh-all-font-lock)

(defvar fountain-trans-regexp
  nil
  "Regular expression for matching transitions.

    Group 1: match forced transition mark
    Group 2: match transition

Constructed with `fountain-init-trans-regexp'. Requires
`fountain-match-trans' for preceding and succeeding blank
lines.")

(defconst fountain-action-regexp
  "^\\(!\\)?\\(.*\\)[\s\t]*$"
  "Regular expression for forced action.

    Group 1: match forced action mark
    Group 2: match trimmed whitespace (export group)")

(defconst fountain-comment-regexp
  (concat "\\(?://[\s\t]*\\(?:.*\\)\\)"
          "\\|"
          "\\(?:\\(?:/\\*\\)[\s\t]*\\(?:\\(?:.\\|\n\\)*?\\)[\s\t]*\\*/\\)")
  "Regular expression for matching comments.")

(defconst fountain-metadata-regexp
  (concat "^\\([^:\s\t\n][^:\n]*\\):[\s\t]*\\(.+\\)?"
          "\\|"
          "^[\s\t]+\\(?2:.+\\)")
  "Regular expression for matching multi-line metadata values.
Requires `fountain-match-metadata' for `bobp'.")

(defconst fountain-character-regexp
  (concat "^[\s\t]*\\(?1:\\(?:"
          "\\(?2:@\\)\\(?3:\\(?4:[^<>\n]+?\\)\\(?:[\s\t]*(.*?)\\)*?\\)"
          "\\|"
          "\\(?3:\\(?4:[^!#a-z<>\n]*?[A-Z][^a-z<>\n]*?\\)\\(?:[\s\t]*(.*?)\\)*?\\)"
          "\\)[\s\t]*\\(?5:\\^\\)?\\)[\s\t]*$")
  "Regular expression for matching character names.

    Group 1: match trimmed whitespace
    Group 2: match leading @ (for forced element)
    Group 3: match character name and parenthetical (export group)
    Group 4: match character name only
    Group 5: match trailing ^ (for dual dialog)

Requires `fountain-match-character' for preceding blank line.")

(defconst fountain-dialog-regexp
  "^\\(\s\s\\)$\\|^[\s\t]*\\([^<>\n]+?\\)[\s\t]*$"
  "Regular expression for matching dialogue.

    Group 1: match trimmed whitespace

Requires `fountain-match-dialog' for preceding character,
parenthetical or dialogue.")

(defconst fountain-paren-regexp
  "^[\s\t]*([^)\n]*)[\s\t]*$"
  "Regular expression for matching parentheticals.

Requires `fountain-match-paren' for preceding character or
dialogue.")

(defconst fountain-page-break-regexp
  "^[\s\t]*\\(=\\{3,\\}\\)[\s\t]*\\([a-z0-9\\.-]+\\)?.*$"
  "Regular expression for matching page breaks.

    Group 1: leading ===
    Group 2: forced page number (export group)")

(defconst fountain-note-regexp
  "\\[\\[[\s\t]*\\(\\(?:.\\|\n\\)*?\\)[\s\t]*]]"
  "Regular expression for matching notes.

    Group 1: note contents (export group)")

(defconst fountain-section-heading-regexp
  "^\\(?1:#\\{1,5\\}\\)[\s\t]*\\(?2:[^#\n].*?\\)[\s\t]*$"
  "Regular expression for matching section headings.

    Group 1: match leading #'s
    Group 2: match heading")

(defconst fountain-synopsis-regexp
  "^\\(\\(=\\)[\s\t]*\\)\\([^=\n].*?\\)$"
  "Regular expression for matching synopses.

    Group 1: leading = and whitespace
    Group 2: leading =
    Group 3: synopsis (export group)")

(defconst fountain-center-regexp
  "^[\s\t]*\\(>\\)[\s\t]*\\(.+?\\)[\s\t]*\\(<\\)[\s\t]*$"
  "Regular expression for matching centered text.

    Group 1: match leading >
    Group 2: match center text (export group)
    Group 3: match trailing <")

(defconst fountain-underline-regexp
  "\\(?:^\\|[^\\]\\)\\(\\(_\\)\\([^\n\s\t_][^_\n]*?\\)\\(\\2\\)\\)"
  "Regular expression for matching underlined text.")

(defconst fountain-italic-regexp
  "\\(?:^\\|[^\\*\\]\\)\\(\\(\\*\\)\\([^\n\s\t\\*][^\\*\n]*?\\)\\(\\2\\)\\)"
  "Regular expression for matching italic text.")

(defconst fountain-bold-regexp
  "\\(?:^\\|[^\\]\\)\\(\\(\\*\\*\\)\\([^\n\s\t\\*][^\\*\n]*?\\)\\(\\2\\)\\)"
  "Regular expression for matching bold text.")

(defconst fountain-bold-italic-regexp
  "\\(?:^\\|[^\\]\\)\\(\\(\\*\\*\\*\\)\\([^\n\s\t\\*][^\\*\n]*?\\)\\(\\2\\)\\)"
  "Regular expression for matching bold-italic text.

Due to the problematic nature of the syntax,
bold-italic-underlined text must be specified with the
bold-italic delimiters together, e.g.

    This text is _***ridiculously important***_.
    This text is ***_stupendously significant_***.")

(defconst fountain-lyrics-regexp
  "^\\(~[\s\t]*\\)\\(.+\\)"
  "Regular expression for matching lyrics.")


;;; Faces

(defgroup fountain-faces ()
  "\\<fountain-mode-map>Faces used in `fountain-mode'.
There are three levels of `font-lock-mode' decoration:

    1 (minimum):
        Comments
        Syntax Characters

    2 (default):
        Comments
        Syntax Characters
        Metadata
        Scene Headings
        Section Headings
        Synopses
        Notes

    3 (maximum):
        Comments
        Syntax Characters
        Metadata Keys
        Metadata Values
        Section Headings
        Scene Headings
        Synopses
        Notes
        Character Names
        Parentheticals
        Dialog
        Transitions
        Center Text

To switch between these levels, customize the value of
`font-lock-maximum-decoration'. This can be set with
\\[fountain-set-font-lock-decoration]."
  :prefix "fountain-"
  :link '(info-link "(emacs) Font Lock")
  :group 'fountain)

(defface fountain
  '((t nil))
  "Default base-level face for `fountain-mode' buffers.")

(defface fountain-action
  '((t nil))
  "Default face for action.")

(defface fountain-comment
  '((t (:inherit shadow)))
  "Default face for comments (boneyard).")

(defface fountain-non-printing
  '((t (:inherit fountain-comment)))
  "Default face for emphasis delimiters and syntax characters.")

(defface fountain-metadata-key
  '((t (:inherit font-lock-constant-face)))
  "Default face for metadata keys.")

(defface fountain-metadata-value
  '((t (:inherit font-lock-keyword-face)))
  "Default face for metadata values.")

(defface fountain-page-break
  '((t (:inherit font-lock-constant-face)))
  "Default face for page breaks.")

(defface fountain-page-number
  '((t (:inherit font-lock-warning-face)))
  "Default face for page numbers.")

(defface fountain-scene-heading
  '((t (:inherit font-lock-function-name-face)))
  "Default face for scene headings.")

(defface fountain-paren
  '((t (:inherit font-lock-builtin-face)))
  "Default face for parentheticals.")

(defface fountain-center
  '((t nil))
  "Default face for centered text.")

(defface fountain-note
  '((t (:inherit font-lock-comment-face)))
  "Default face for notes.")

(defface fountain-section-heading
  '((t (:inherit font-lock-keyword-face)))
  "Default face for section headings.")

(defface fountain-synopsis
  '((t (:inherit font-lock-type-face)))
  "Default face for synopses.")

(defface fountain-character
  '((t (:inherit font-lock-variable-name-face)))
  "Default face for characters.")

(defface fountain-dialog
  '((t (:inherit font-lock-string-face)))
  "Default face for dialog.")

(defface fountain-trans
  '((t (:inherit font-lock-builtin-face)))
  "Default face for transitions.")

(defface fountain-template
  '((t (:inherit font-lock-preprocessor-face)))
  "Default face for template keys.")


;;; Initializing

(defcustom fountain-scene-heading-prefix-list
  '("INT" "EXT" "EST" "INT./EXT." "INT/EXT" "I/E")
  "List of scene heading prefixes (case insensitive).
Any scene heading prefix can be followed by a dot and/or a space,
so the following are equivalent:

    INT HOUSE - DAY

    INT. HOUSE - DAY"
  :type '(repeat (string :tag "Prefix"))
  :group 'fountain
  :set (lambda (symbol value)
         (set-default symbol value)
         ;; Don't call fountain-init-*' while in the middle of
         ;; loading this file!
         (when (featurep 'fountain-mode)
           (fountain-init-scene-heading-regexp)
           (dolist (buffer (buffer-list))
             (with-current-buffer buffer
               (when (derived-mode-p 'fountain-mode)
                 (fountain-init-outline-regexp)
                 (font-lock-refresh-defaults)))))))

(defcustom fountain-trans-suffix-list
  '("TO:" "WITH:" "FADE OUT" "TO BLACK")
  "List of transition suffixes (case insensitive).
This list is used to match the endings of transitions,
e.g. `TO:' will match both the following:

    CUT TO:

    DISSOLVE TO:"
  :type '(repeat (string :tag "Suffix"))
  :group 'fountain
  :set (lambda (symbol value)
         (set-default symbol value)
         ;; Don't call fountain-*' while in the middle of
         ;; loading this file!
         (when (featurep 'fountain-mode)
           (fountain-init-trans-regexp)
           (dolist (buffer (buffer-list))
             (with-current-buffer buffer
               (when (derived-mode-p 'fountain-mode)
                 (font-lock-refresh-defaults)))))))

(defun fountain-init-scene-heading-regexp ()
  "Initialize scene heading regular expression.
Uses `fountain-scene-heading-prefix-list' to create non-forced
scene heading regular expression."
  (setq fountain-scene-heading-regexp
        (concat
         "^\\(?:"
         ;; Group 1: match leading . (for forced scene heading)
         "\\(?1:\\.\\)"
         ;; Group 2: match scene heading without scene number
         "\\(?2:\\<"
         ;; Group 4: match location
         "\\(?4:.+?\\)"
         ;; Group 5: match suffix separator
         "\\(?:\\(?5:" fountain-scene-heading-suffix-sep "\\)"
         ;; Group 6: match suffix
         "\\(?6:.+\\)?\\)?"
         "\\)\\|"
         ;; Group 2: match scene heading without scene number
         "^\\(?2:"
         ;; Group 3: match INT/EXT
         "\\(?3:" (regexp-opt fountain-scene-heading-prefix-list) "\\.?\s+\\)"
         ;; Group 4: match location
         "\\(?4:.+?\\)?"
         ;; Group 5: match suffix separator
         "\\(?:\\(?5:" fountain-scene-heading-suffix-sep "\\)"
         ;; Group 6: match suffix
         "\\(?6:.+?\\)?\\)?"
         "\\)\\)"
         ;;; Match scene number
         "\\(?:"
         ;; Group 7: match space between scene heading and scene number
         "\\(?7:\s+\\)"
         ;; Group 8: match first # delimiter
         "\\(?8:#\\)"
         ;; Group 9: match scene number
         "\\(?9:[0-9a-z\\.-]+\\)"
         ;; Group 10: match last # delimiter
         "\\(?10:#\\)\\)?"
         "\s*$")))

(defun fountain-init-trans-regexp ()
  "Initialize transition regular expression.
Uses `fountain-trans-suffix-list' to create non-forced tranistion
regular expression."
  (setq fountain-trans-regexp
        (concat
         "^\\(?:[\s\t]*"
         ;; Group 1: match forced transition mark
         "\\(>\\)[\s\t]*"
         ;; Group 2: match forced transition
         "\\([^<>\n]*?\\)"
         "\\|"
         ;; Group 2: match transition
         "\\(?2:[[:upper:]\s\t]*"
         (upcase (regexp-opt fountain-trans-suffix-list))
         "\\)"
         "\\)[\s\t]*$")))

(defun fountain-init-outline-regexp ()
  "Initialize `outline-regexp'."
  (setq-local outline-regexp
              (concat fountain-section-heading-regexp
                      "\\|"
                      fountain-scene-heading-regexp)))

(defun fountain-init-imenu-generic-expression ()
  "Initialize `imenu-generic-expression'."
  ;; FIXME: each of these should be a boolean user option to allow the
  ;; user to choose which appear in the imenu list.
  (setq imenu-generic-expression
        (list
         (list "Notes" fountain-note-regexp 1)
         (list "Scene Headings" fountain-scene-heading-regexp 2)
         (list "Sections" fountain-section-heading-regexp 0))))

(defun fountain-init-vars ()
  "Initialize important variables.
Needs to be called for every Fountain buffer because some
variatbles are required for functions to operate with temporary
buffers."
  (fountain-init-scene-heading-regexp)
  (fountain-init-trans-regexp)
  (fountain-init-outline-regexp)
  (fountain-init-imenu-generic-expression)
  (modify-syntax-entry (string-to-char "/") ". 14" nil)
  (modify-syntax-entry (string-to-char "*") ". 23" nil)
  (setq-local comment-start "/*")
  (setq-local comment-end "*/")
  (setq-local comment-use-syntax t)
  (setq-local font-lock-comment-face 'fountain-comment)
  (setq-local page-delimiter fountain-page-break-regexp)
  (setq-local outline-level #'fountain-outline-level)
  (setq-local require-final-newline mode-require-final-newline)
  (setq-local completion-cycle-threshold t)
  (setq-local completion-at-point-functions
              '(fountain-completion-at-point))
  (setq-local font-lock-extra-managed-props
              '(line-prefix wrap-prefix invisible))
  ;; This should be temporary. Feels better to ensure appropriate
  ;; case-fold within each function.
  (setq case-fold-search t)
  (setq font-lock-multiline 'undecided)
  (setq font-lock-defaults '(fountain-init-font-lock))
  (add-to-invisibility-spec (cons 'outline t))
  (when fountain-hide-emphasis-delim
    (add-to-invisibility-spec 'fountain-emphasis-delim))
  (when fountain-hide-syntax-chars
    (add-to-invisibility-spec 'fountain-syntax-chars)))


;;; Emacs Bugs

(defcustom fountain-patch-emacs-bugs
  t
  "If non-nil, attempt to patch known bugs in Emacs.
See function `fountain-patch-emacs-bugs'."
  :type 'boolean
  :safe 'booleanp
  :group 'fountain)

(defun fountain-patch-emacs-bugs ()
  "Attempt to patch known bugs in Emacs.

In Emacs versions prior to 26, adds advice to override
`outline-invisible-p' to return non-nil only if the character
after POS or point has invisible text property eq to 'outline.
See <http://debbugs.gnu.org/24073>."
  ;; In Emacs version prior to 26, `outline-invisible-p' returns non-nil for ANY
  ;; invisible property of text at point. We want to only return non-nil if
  ;; property is 'outline
  (unless (or (advice-member-p 'fountain-outline-invisible-p 'outline-invisible-p)
              (<= 26 emacs-major-version))
    (advice-add 'outline-invisible-p :override #'fountain-outline-invisible-p)
    ;; Because `outline-invisible-p' is an inline function, we need to
    ;; reevaluate those functions that called the original bugged version.
    ;; This is impossible for users who have installed Emacs without
    ;; uncompiled source, so we need to demote errors.
    (with-demoted-errors "Error: %S"
      (dolist (fun '(outline-back-to-heading
                     outline-on-heading-p
                     outline-next-visible-heading))
        (let ((source (find-function-noselect fun)))
          (with-current-buffer (car source)
            (goto-char (cdr source))
            (eval (read (current-buffer)) lexical-binding))))
      (message "fountain-mode: Function `outline-invisible-p' has been patched"))))


;;; Element Matching

(defun fountain-blank-before-p ()
  "Return non-nil if preceding line is blank or a comment."
  (save-excursion
    (save-restriction
      (widen)
      (beginning-of-line)
      (or (bobp)
          (progn (forward-line -1)
                 (or (and (bolp) (eolp))
                     (progn (end-of-line)
                            (forward-comment -1))))))))

(defun fountain-blank-after-p ()
  "Return non-nil if following line is blank or a comment."
  (save-excursion
    (save-restriction
      (widen)
      (forward-line)
      (or (eobp)
          (and (bolp) (eolp))
          (forward-comment 1)))))

(defun fountain-match-metadata ()
  "Match metadata if point is at metadata, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (and (looking-at fountain-metadata-regexp)
         (save-match-data
           (save-restriction
             (widen)
             (or (bobp)
                 (and (forward-line -1)
                      (fountain-match-metadata))))))))

(defun fountain-match-page-break ()
  "Match page break if point is at page break, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (looking-at fountain-page-break-regexp)))

(defun fountain-match-section-heading ()
  "Match section heading if point is at section heading, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (looking-at fountain-section-heading-regexp)))

(defun fountain-match-synopsis ()
  "Match synopsis if point is at synopsis, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (looking-at fountain-synopsis-regexp)))

(defun fountain-match-note ()
  "Match note if point is at note, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (or (looking-at fountain-note-regexp)
        (save-restriction
          (widen)
          (let ((x (point)))
            (and (re-search-backward "\\[\\[" nil t)
                 (looking-at fountain-note-regexp)
                 (< x (match-end 0))))))))

(defun fountain-match-scene-heading ()
  "Match scene heading if point is at a scene heading, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (and (looking-at fountain-scene-heading-regexp)
         (fountain-blank-before-p))))

(defun fountain-match-character ()
  "Match character if point is at character, nil otherwise."
  (unless (fountain-match-scene-heading)
    (save-excursion
      (beginning-of-line)
      (and (let (case-fold-search)
             (looking-at fountain-character-regexp))
           (fountain-blank-before-p)
           (not (fountain-blank-after-p))))))

(defun fountain-match-dialog ()
  "Match dialog if point is at dialog, nil otherwise."
  (unless (or (and (bolp) (eolp))
              (fountain-match-paren)
              (fountain-match-note))
    (save-excursion
      (beginning-of-line)
      (and (looking-at fountain-dialog-regexp)
           (save-match-data
             (save-restriction
               (widen)
               (unless (bobp)
                 (forward-line -1)
                 (or (fountain-match-character)
                     (fountain-match-paren)
                     (fountain-match-dialog)))))))))

(defun fountain-match-paren ()
  "Match parenthetical if point is at a paranthetical, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (and (looking-at fountain-paren-regexp)
         (save-match-data
           (save-restriction
             (widen)
             (unless (bobp)
               (forward-line -1)
               (or (fountain-match-character)
                   (fountain-match-dialog))))))))

(defun fountain-match-trans ()
  "Match transition if point is at a transition, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (and (let (case-fold-search)
           (looking-at fountain-trans-regexp))
         (fountain-blank-before-p)
         (fountain-blank-after-p))))

(defun fountain-match-center ()
  "Match centered text if point is at centered text, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (looking-at fountain-center-regexp)))

;; FIXME: too expensive
(defun fountain-match-action ()
  "Match action text if point is at action, nil otherwise.
Assumes that all other element matching has been done."
  (save-excursion
    (save-restriction
      (widen)
      (beginning-of-line)
      (or (and (looking-at fountain-action-regexp)
               (match-string 1))
          (and (not (or (and (bolp) (eolp))
                        (fountain-match-section-heading)
                        (fountain-match-scene-heading)
                        (fountain-match-template)
                        (fountain-match-page-break)
                        (fountain-match-character)
                        (fountain-match-dialog)
                        (fountain-match-paren)
                        (fountain-match-trans)
                        (fountain-match-center)
                        (fountain-match-synopsis)
                        (fountain-match-metadata)
                        (fountain-match-note)))
               (looking-at fountain-action-regexp))))))

(defun fountain-get-element ()
  "Return element at point as a symbol."
  (cond
   ((and (bolp) (eolp)) nil)
   ((fountain-match-metadata) 'metadata)
   ((fountain-match-section-heading) 'section-heading)
   ((fountain-match-scene-heading) 'scene-heading)
   ((and (fountain-match-character)
         (fountain-read-dual-dialog))
    'character-dd)
   ((fountain-match-character) 'character)
   ((and (fountain-match-dialog)
         (fountain-read-dual-dialog))
    'lines-dd)
   ((fountain-match-dialog) 'lines)
   ((and (fountain-match-paren)
         (fountain-read-dual-dialog))
    'paren-dd)
   ((fountain-match-paren) 'paren)
   ((fountain-match-trans) 'trans)
   ((fountain-match-center) 'center)
   ((fountain-match-synopsis) 'synopsis)
   ((fountain-match-page-break) 'page-break)
   ((fountain-match-note) 'note)
   (t 'action)))

(defmacro define-fountain-font-lock-matcher (func)
  (let ((funcname (intern (format "%s-font-lock" func)))
        (docstring (format "\
Call `%s' on each line before LIMIT.
Return non-nil if match occurs." func)))
    `(defun ,funcname (limit)
       ,docstring
       (let (match)
         (while (and (null match)
                     (< (point) limit))
           (when (,func) (setq match t))
           (forward-line))
         match))))

(defvar fountain-element-list
  '((section-heading
     :tag "Section Heading"
     :matcher fountain-section-heading-regexp
     :highlight ((2 0 fountain-section-heading)
                 (2 1 fountain-non-printing prepend))
     :parser fountain-parse-section
     :align fountain-align-section-heading
     :fill fountain-fill-section-heading)
    (scene-heading
     :tag "Scene Heading"
     :matcher (define-fountain-font-lock-matcher fountain-match-scene-heading)
     :highlight ((2 0 fountain-scene-heading)
                 (2 7 fountain-scene-heading nil t)
                 (2 8 fountain-non-printing prepend t fountain-syntax-chars)
                 (2 9 fountain-scene-heading prepend t)
                 (2 10 fountain-non-printing prepend t fountain-syntax-chars)
                 (3 1 fountain-non-printing prepend t fountain-syntax-chars))
     :parser fountain-parse-scene
     :align fountain-align-scene-heading
     :fill fountain-fill-scene-heading)
    (action
     :tag "Action"
     :matcher (define-fountain-font-lock-matcher fountain-match-action)
     :highlight ((1 0 fountain-action)
                 (3 1 fountain-non-printing t t fountain-syntax-chars))
     :parser fountain-parse-action
     :align fountain-align-action
     :fill fountain-fill-action)
    (character
     :tag "Character Name"
     :matcher (define-fountain-font-lock-matcher fountain-match-character)
     :highlight ((3 0 fountain-character)
                 (3 2 fountain-non-printing t t fountain-syntax-chars)
                 (3 5 highlight prepend t))
     :parser fountain-parse-dialog
     :align fountain-align-character
     :fill fountain-fill-character)
    (character-dd
     :tag "Dual-Dialogue Character Name"
     :matcher (define-fountain-font-lock-matcher fountain-match-character)
     :highlight ((3 0 fountain-character)
                 (3 2 fountain-non-printing t t fountain-syntax-chars)
                 (3 5 highlight prepend t))
     :parser fountain-parse-dialog
     :align fountain-align-character
     :fill fountain-fill-dual-character)
    (lines
     :tag "Dialogue"
     :matcher (define-fountain-font-lock-matcher fountain-match-dialog)
     :highlight ((3 0 fountain-dialog))
     :parser fountain-parse-lines
     :align fountain-align-dialog
     :fill fountain-fill-dialog)
    (lines-dd
     :tag "Dual-Dialogue"
     :matcher (define-fountain-font-lock-matcher fountain-match-dialog)
     :highlight ((3 0 fountain-dialog))
     :parser fountain-parse-lines
     :align fountain-align-dialog
     :fill fountain-fill-dual-dialog)
    (paren
     :tag "Parenthetical"
     :matcher (define-fountain-font-lock-matcher fountain-match-paren)
     :highlight ((3 0 fountain-paren))
     :parser fountain-parse-paren
     :align fountain-align-paren
     :fill fountain-fill-paren)
    (paren-dd
     :tag "Dual-Dialogue Parenthetical"
     :matcher (define-fountain-font-lock-matcher fountain-match-paren)
     :highlight ((3 0 fountain-paren))
     :parser fountain-parse-paren
     :align fountain-align-paren
     :fill fountain-fill-dual-paren)
    (trans
     :tag: "Transition"
     :matcher (define-fountain-font-lock-matcher fountain-match-trans)
     :highlight ((3 0 fountain-trans)
                 (2 1 fountain-non-printing t t fountain-syntax-chars))
     :parser fountain-parse-trans
     :align fountain-align-trans
     :fill fountain-fill-trans)
    (center
     :tag "Center Text"
     :matcher fountain-center-regexp
     :highlight ((2 1 fountain-non-printing t nil fountain-syntax-chars)
                 (2 3 fountain-non-printing t nil fountain-syntax-chars))
     :parser fountain-parse-center
     :align fountain-align-center
     :fill fountain-fill-action)
    (page-break
     :tage "Page Break"
     :matcher fountain-page-break-regexp
     :highlight ((2 0 fountain-page-break)
                 (2 2 fountain-page-number t t))
     :parser fountain-parse-page-break)
    (synopsis
     :tag "Synopsis"
     :matcher (define-fountain-font-lock-matcher fountain-match-synopsis)
     :highlight ((2 0 fountain-synopsis nil nil fountain-synopsis)
                 (2 1 fountain-non-printing prepend nil fountain-syntax-chars))
     :parser fountain-parse-synopsis
     :align fountain-align-synopsis
     :fill fountain-fill-action)
    (note
     :tag "Note"
     :matcher (define-fountain-font-lock-matcher fountain-match-note)
     :highlight ((2 0 fountain-note))
     :parser fountain-parse-note
     :fill fountain-fill-note)
    (metadata
     :tag "Metadata"
     :matcher (define-fountain-font-lock-matcher fountain-match-metadata)
     :highlight ((3 0 fountain-metadata-key nil t)
                 (2 2 fountain-metadata-value t t)))
    (underline
     :tag "Underline"
     :matcher fountain-underline-regexp
     :highlight ((3 2 fountain-non-printing prepend nil fountain-emphasis-delim)
                 (1 1 underline prepend)
                 (3 4 fountain-non-printing prepend nil fountain-emphasis-delim)))
    (italic
     :tag "Italics"
     :matcher fountain-italic-regexp
     :highlight ((3 2 fountain-non-printing prepend nil fountain-emphasis-delim)
                 (1 1 italic prepend)
                 (3 4 fountain-non-printing prepend nil fountain-emphasis-delim)))
    (bold
     :tag "Bold"
     :matcher fountain-bold-regexp
     :highlight ((3 2 fountain-non-printing prepend nil fountain-emphasis-delim)
                 (1 1 bold prepend)
                 (3 4 fountain-non-printing prepend nil fountain-emphasis-delim)))
    (bold-italic
     :tag "Bold Italic"
     :matcher fountain-bold-italic-regexp
     :highlight ((3 2 fountain-non-printing prepend nil fountain-emphasis-delim)
                 (1 1 bold-italic prepend)
                 (3 4 fountain-non-printing prepend nil fountain-emphasis-delim)))
    (lyrics
     :tag "Lyrics"
     :matcher fountain-lyrics-regexp
     :highlight ((3 1 fountain-non-printing prepend nil fountain-emphasis-delim)
                 (2 2 italic prepend))))
  "Association list of Fountain elements and their properties.
Includes references to various functions and variables.

Takes the form:

    (ELEMENT KEYWORD PROPERTY)

:highlight keyword property takes the form:

    (LEVEL SUBEXP FACENAME [OVERRIDE LAXMATCH INVISIBLE])")


;;; Auto-completion

(defvar-local fountain-completion-locations
  nil
  "List of scene locations in the current buffer.")

(defvar-local fountain-completion-characters
  nil
  "List of characters in the current buffer.
Each element is a cons (NAME . OCCUR) where NAME is a string, and
OCCUR is an integer representing the character's number of
occurrences. ")

(defvar fountain-completion-additional-characters
  nil
  "List of additional character strings to offer for completion.
Case insensitive, all character names will be made uppercase.

This is really only useful when working with multiple files and
set as a per-directory local variable.

See (info \"(emacs) Directory Variables\")")

(defvar fountain-completion-additional-locations
  nil
  "List of additional location strings to offer for completion.
Case insensitive, all locations will be made uppercase.

This is really only useful when working with multiple files and
set as a per-directory local variable.

See (info \"(emacs) Directory Variables\")")

(defun fountain-completion-get-characters ()
  "Return a list of characters for completion.

First, return second-last speaking character, followed by each
previously speaking character within scene. After that, return
characters from `fountain-completion-additional-characters' then
`fountain-completion-characters'.

n.b. `fountain-completion-additional-characters' are offered as
candidates ahead of `fountain-completion-characters' because
these need to be manually set, and so are considered more
important."
  (let (scene-characters
        alt-character
        contd-character
        rest-characters)
    (save-excursion
      (save-restriction
        (widen)
        (fountain-forward-character 0 'scene)
        (while (not (or (bobp) (fountain-match-scene-heading)))
          (when (fountain-match-character)
            (let ((character (match-string-no-properties 4)))
              (unless (member character scene-characters)
                (push (list character) scene-characters))))
          (fountain-forward-character -1 'scene))))
    (setq scene-characters (reverse scene-characters)
          alt-character (cadr scene-characters)
          contd-character (car scene-characters)
          rest-characters (cddr scene-characters)
          scene-characters nil)
    (when rest-characters
      (setq scene-characters rest-characters))
    (when contd-character
      (setq scene-characters
            (cons contd-character scene-characters)))
    (when alt-character
      (setq scene-characters
            (cons alt-character scene-characters)))
    (append scene-characters
            (mapcar 'upcase fountain-completion-additional-characters)
            fountain-completion-characters)))

(defun fountain-completion-at-point ()
  "\\<fountain-mode-map>Return completion table for entity at point.
Trigger completion with \\[fountain-dwim].

1. If point is at a scene heading and matches
`fountain-scene-heading-suffix-sep', offer completion candidates
from `fountain-scene-heading-suffix-list'.

2. If point is at a line matching
`fountain-scene-heading-prefix-list', offer completion candidates
from `fountain-completion-locations' and
`fountain-completion-additional-locations'.

3. If point is at beginning of line with a preceding blank line,
offer completion candidates from `fountain-completion-characters'
and `fountain-completion-additional-characters'. For more
information of character completion sorting, see
`fountain-completion-get-characters'.

Added to `completion-at-point-functions'."
  (cond ((and (fountain-match-scene-heading)
              (match-string 5))
         ;; Return scene heading suffix completion
         (list (match-end 5)
               (point)
               (completion-table-case-fold
                fountain-scene-heading-suffix-list)))
        ((and (fountain-match-scene-heading)
              (match-string 3))
         ;; Return scene location completion
         (list (match-end 3)
               (point)
               (completion-table-case-fold
                (append
                 (mapcar 'upcase fountain-completion-additional-locations)
                 fountain-completion-locations))))
        ((and (fountain-match-scene-heading)
              (match-string 1))
         ;; Return scene location completion (forced)
         (list (match-end 1)
               (point)
               (completion-table-case-fold
                (append
                 (mapcar 'upcase fountain-completion-additional-locations)
                 fountain-completion-locations))))
        ((and (eolp)
              (fountain-blank-before-p))
         ;; Return character completion
         (list (line-beginning-position)
               (point)
               (completion-table-case-fold
                (lambda (string pred action)
                  (if (eq action 'metadata)
                      (list 'metadata
                            (cons 'display-sort-function 'identity)
                            (cons 'cycle-sort-function 'identity))
                    (complete-with-action
                     action (fountain-completion-get-characters)
                     string pred))))))))

(defun fountain-completion-update ()
  "Update completion candidates for current buffer.

While `fountain-completion-locations' are left unsorted for
`completion-at-point' to perform sorting,
`fountain-completion-characters' are sorted by number of lines.
For more information on character completion sorting, see
`fountain-completion-get-characters'.

Add to `fountain-mode-hook' to have completion upon load."
  (interactive)
  (setq fountain-completion-locations nil
        fountain-completion-characters nil)
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (point-min))
      (while (< (point) (point-max))
        (when (fountain-match-scene-heading)
          (let ((location (match-string-no-properties 4)))
            (unless (member location fountain-completion-locations)
              (push location fountain-completion-locations))))
        (fountain-forward-scene 1))
      (goto-char (point-min))
      (while (< (point) (point-max))
        (when (fountain-match-character)
          (let ((character (match-string-no-properties 4))
                candidate lines)
            (setq candidate (assoc-string character
                                          fountain-completion-characters)
                  lines (cdr candidate))
            (if (null lines)
                (push (cons character 1) fountain-completion-characters)
              (cl-incf (cdr candidate)))))
        (fountain-forward-character 1))
      (setq fountain-completion-characters
            (sort fountain-completion-characters
                  (lambda (a b) (< (cdr b) (cdr a)))))))
  (message "Completion candidates updated"))


;;; Pages

(defgroup fountain-pages ()
  "Options for calculating page length."
  :group 'fountain
  :prefix "fountain-page-")

(define-obsolete-variable-alias 'fountain-export-page-size
  'fountain-page-size "3.0.0")
(defcustom fountain-page-size
  'letter
  "Paper size to use on export."
  :type '(radio (const :tag "US Letter" letter)
                (const :tag "A4" a4)))

(define-obsolete-variable-alias 'fountain-pages-max-lines
  'fountain-page-max-lines "3.0.0")
(defcustom fountain-page-max-lines
  '((letter . 55) (a4 . 60))
  "Integer representing maximum number of lines on a page.

WARNING: if you change this option after locking pages in a
script, you may get incorrect output."
  :type '(choice integer
                 (list (cons (const :tag "US Letter" letter) integer)
                       (cons (const :tag "A4" a4) integer))))

(define-obsolete-variable-alias 'fountain-pages-ignore-narrowing
  'fountain-page-ignore-restriction "3.0.0")
(defcustom fountain-page-ignore-restriction
  nil
  "Non-nil if counting pages should ignore buffer narrowing."
  :type 'boolean
  :safe 'booleanp)

(defcustom fountain-page-size
  'letter
  "Paper size to use on export."
  :type '(radio (const :tag "US Letter" letter)
                (const :tag "A4" a4)))

(defun fountain-goto-page-break-point (&optional export-elements)
  "Move point to appropriate place to break a page.
This is usually before point, but may be after if only skipping
over whitespace.

Comments are assumed to be deleted."
  (when (looking-at fountain-more-dialog-string) (forward-line))
  (when (looking-at "[\n\s\t]*\n") (goto-char (match-end 0)))
  (let ((element (fountain-get-element)))
    (cond
     ;; If element is not included in export, we can safely break
     ;; before.
     ((not (memq element (or export-elements
                             (fountain-get-export-elements))))
      (beginning-of-line))
     ;; We cannot break page in dual dialogue. If we're at right dual
     ;; dialogue, skip back to previous character.
     ((and (memq element '(character-dd lines-dd paren-dd))
           (eq (fountain-read-dual-dialog) 'right))
      (fountain-forward-character 0)
      (fountain-forward-character -1))
     ;; If we're at left dual dialogue, break at character.
     ((memq element '(character-dd lines-dd paren-dd))
      (fountain-forward-character 0))
     ;; If we're are a section heading, scene heading or character, we
     ;; can safely break before.
     ((memq element '(section-heading scene-heading character))
      (beginning-of-line))
     ;; If we're at a parenthetical, check if the previous line is a
     ;; character. and if so call recursively on that element.
     ((eq element 'paren)
      (beginning-of-line)
      (let ((x (point)))
        (backward-char)
        (if (fountain-match-character)
            (progn
              (beginning-of-line)
              (fountain-goto-page-break-point export-elements))
          ;; Otherwise parenthetical is mid-dialogue, so get character
          ;; name and break at this element.
          (goto-char x))))
     ;; If we're at dialogue, skip over spaces then go to the beginning
     ;; of the current sentence. If previous line is a character or
     ;; parenthetical, call recursively on that element. Otherwise,
     ;; break page here.
     ((eq element 'lines)
      (skip-chars-forward "\s\t")
      (unless (or (bolp)
                  (looking-back (sentence-end) nil))
        (forward-sentence -1))
      (let ((x (point)))
        (backward-char)
        (if (or (fountain-match-character)
                (fountain-match-paren))
            (progn
              (beginning-of-line)
              (fountain-goto-page-break-point export-elements))
          (goto-char x))))
     ;; If we're at a transition or center text, skip backwards to
     ;; previous element and call recursively on that element.
     ((memq element '(trans center))
      (skip-chars-backward "\n\s\t")
      (beginning-of-line)
      (fountain-goto-page-break-point export-elements))
     ;; If we're at action, skip over spaces then go to the beginning
     ;; of the current sentence.
     ((eq element 'action)
      (skip-chars-forward "\s\t")
      (unless (or (bolp)
                  (looking-back (sentence-end) nil))
        (forward-sentence -1))
      ;; Then, try to skip back to the previous element. If it is a
      ;; scene heading, call recursively on that element. Otherwise,
      ;; break page here.
      (let ((x (point)))
        (skip-chars-backward "\n\s\t")
        (beginning-of-line)
        (if (fountain-match-scene-heading)
            (fountain-goto-page-break-point export-elements)
          (goto-char x)))))))

(defun fountain-move-to-fill-width (element)
  "Move point to column of ELEMENT fill limit suitable for breaking line.
Skip over comments."
  (let ((fill-width
         (cdr (symbol-value
               (plist-get (cdr (assq element fountain-element-list))
                          :fill)))))
    (let ((i 0))
      (while (and (< i fill-width) (not (eolp)))
        (cond ((= (syntax-class (syntax-after (point))) 0)
               (forward-char 1)
               (setq i (1+ i)))
              ((forward-comment 1))
              (t
               (forward-char 1)
               (setq i (1+ i))))))
    (skip-chars-forward "\s\t")
    (when (eolp) (forward-line))
    (unless (bolp) (fill-move-to-break-point (line-beginning-position)))))

(defun fountain-forward-page (&optional export-elements)
  "Move point forward by an approximately page.

Moves forward from point, which is unlikely to correspond to
final exported pages and so should not be used interactively.

To speed up this function, supply EXPORT-ELEMENTS with
`fountain-get-export-elements'."
  (let ((skip-whitespace-fun
         (lambda ()
           (when (looking-at "[\n\s\t]*\n")
             (goto-char (match-end 0))))))
    (unless export-elements
      (setq export-elements (fountain-get-export-elements)))
    (while (fountain-match-metadata)
      (forward-line 1))
    ;; Pages don't begin with blank space, so skip over any at point.
    (funcall skip-whitespace-fun)
    ;; If we're at a page break, move to its end and skip over
    ;; whitespace.
    (when (fountain-match-page-break)
      (end-of-line)
      (funcall skip-whitespace-fun))
    ;; Start counting lines.
    (let ((page-lines
           (cdr (assq fountain-page-size fountain-page-max-lines)))
          (line-count 0)
          (line-count-left 0)
          (line-count-right 0)
          element)
      ;; Begin the main loop, which only halts if we reach the end
      ;; of buffer, a forced page break, or after the maximum lines
      ;; in a page.
      (while (and (< line-count page-lines)
                  (not (eobp))
                  (not (fountain-match-page-break)))
        (cond
         ;; If we're at the end of a line (but not also the
         ;; beginning, i.e. not a blank line) then move forward a
         ;; line and increment line-count.
         ((and (eolp) (not (bolp)))
          (forward-line)
          (setq line-count (1+ line-count)))
         ;; If we're looking at newline, skip over it and any
         ;; whitespace and increment line-count.
         ((funcall skip-whitespace-fun)
          (setq line-count (1+ line-count)))
         ;; We are at an element. Find what kind of element. If it is
         ;; not included in export, skip over without incrementing
         ;; line-count. Otherwise move to fill-width and increment
         ;; appropriate line-count: for dual-dialogue, increment either
         ;; LINE-COUNT-LEFT/RIGHT, otherwise increment LINE-COUNT. Once
         ;; we're at a blank line, add the greater of the former two to
         ;; the latter.
         ;; FIXME: using block-bounds here could benefit.
         (t
        (let ((element (fountain-get-element))
              (dd (fountain-read-dual-dialog)))
          (if (memq element export-elements)
              (progn
                (fountain-move-to-fill-width element)
                (cond ((eq dd 'left)
                       (setq line-count-left (1+ line-count-left)))
                      ((eq dd 'right)
                       (setq line-count-right (1+ line-count-right)))
                      (t
                       (setq line-count (1+ line-count))))
                (when (and (eolp) (bolp)
                           (< 0 line-count-left) (< 0 line-count-right))
                  (setq line-count
                        (+ line-count (max line-count-left line-count-right)))))
            ;; Element is not exported, so skip it without
            ;; incrementing line-count.
            (end-of-line)
            (funcall skip-whitespace-fun)))))))
    ;; We are not at the furthest point in a page. Skip over any
    ;; remaining whitespace, then go back to page-break point.
    (fountain-goto-page-break-point (or export-elements
                                        (fountain-get-export-elements)))))

(defun fountain-insert-page-break (&optional ask page-num export-elements)
  "Insert a page break at appropriate place preceding point.
When optional argument ASK is non-nil (if prefixed with
\\[universal-argument] when called interactively), prompt for PAGE-NUM
as a string to force the page number."
  (interactive "P")
  (when ask
    (setq page-num (read-string "Page number (RET for none): ")))
  ;; Save a marker where we are.
  (let ((x (point-marker))
        (page-break
         (concat "===" (when (and (stringp page-num)
                                  (< 0 (string-width page-num)))
                         (concat "\s" page-num "\s==="))))
        element)
    ;; Move point to appropriate place to break page.
    (fountain-goto-page-break-point export-elements)
    (setq element (fountain-get-element))
    ;; At this point, element can only be: section-heading,
    ;; scene-heading, character, action, paren or lines. Only paren and
    ;; lines require special treatment.
    (if (memq element '(lines paren))
        (let ((name (fountain-get-character -1)))
          (delete-horizontal-space)
          (unless (bolp) (insert-before-markers "\n"))
          (insert-before-markers
           (concat fountain-more-dialog-string "\n\n"
                   page-break "\n\n"
                   name fountain-contd-dialog-string "\n")))
      ;; Otherwise, insert the page break where we are. If the preceding
      ;; element is a page break, only replace the page number,
      ;; otherwise, insert the page break.
      (if (save-excursion
            (save-restriction
              (widen)
              (skip-chars-backward "\n\s\t")
              (fountain-match-page-break)))
          (replace-match page-break t t)
        (delete-horizontal-space)
        (unless (bolp) (insert-before-markers "\n"))
        (unless (fountain-blank-before-p) (insert-before-markers "\n"))
        (insert-before-markers page-break "\n\n")))
    ;; Return to where we were.
    (goto-char x)
    (set-marker x nil)))

(defun fountain-get-page-count ()
  "Return a cons of the current page number and the total pages."
  (let ((x (point))
        (total 0)
        (current 0)
        (export-elements (fountain-get-export-elements))
        found)
    (save-excursion
      (save-restriction
        (when fountain-page-ignore-restriction (widen))
        (goto-char (point-min))
        (while (< (point) (point-max))
          (fountain-forward-page export-elements)
          (setq total (1+ total))
          (when (and (not found) (< x (point)))
            (setq current total found t)))
        (cons current total)))))

(defun fountain-count-pages ()
  "Message the current page of total pages in current buffer.
n.b. This is an approximate calculation."
  (interactive)
  (let ((pages (fountain-get-page-count)))
    (message "Page %d of %d" (car pages) (cdr pages))))

(defun fountain-paginate-buffer (&optional export-elements)
  "Add forced page breaks to buffer.

Move through buffer with `fountain-forward-page' and call
`fountain-insert-page-break'."
  (interactive)
  (unless export-elements
    (setq export-elements (fountain-get-export-elements)))
  (let ((job (make-progress-reporter "Paginating...")))
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (let ((page 1))
          (fountain-forward-page export-elements)
          (while (< (point) (point-max))
            (setq page (1+ page))
            (fountain-insert-page-break nil (number-to-string page)
                                        export-elements)
            (fountain-forward-page export-elements)
            (progress-reporter-update job))
          (progress-reporter-done job))))))


;;; Templating

(defconst fountain-template-regexp
  "{{[\s\t]*\\([.-a-z0-9]+\\)\\(?::[\s\t]+\\([^{}]+?\\)\\)?[\s\t]*}}"
  "Regular expression for matching template keys.")


;;; Parsing

(defun fountain-get-character (&optional n limit)
  "Return Nth next character (or Nth previous if N is negative).

If N is non-nil, return Nth next character or Nth previous
character if N is negative, otherwise return nil. If N is nil or
0, return character at point, otherwise return nil.

If LIMIT is 'scene, halt at next scene heading. If LIMIT is
'dialog, halt at next non-dialog element."
  (unless n (setq n 0))
  (save-excursion
    (save-restriction
      (widen)
      (fountain-forward-character n limit)
      (when (fountain-match-character)
        (match-string-no-properties 4)))))

(defun fountain-read-metadata ()
  "Read metadata of current buffer and return as a property list.

Key string is slugified using `fountain-slugify', and interned.
Value string remains a string. e.g.

    Draft date: 2015-12-25 -> (draft-date \"2015-12-25\")"
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (point-min))
      (let (list)
        (while (and (bolp)
                    (fountain-match-metadata))
          (let ((key (match-string-no-properties 1))
                (value (match-string-no-properties 2)))
            (forward-line)
            (while (and (fountain-match-metadata)
                        (null (match-string 1)))
              (setq value
                    (concat value (when value "\n")
                            (match-string-no-properties 2)))
              (forward-line))
            (setq list
                  (append list (list (intern (fountain-slugify key))
                                     value)))))
        list))))

(defun fountain-read-dual-dialog (&optional pos)
  "Non-nil if point or POS is within dual dialogue.
Returns \"right\" if within right-side dual dialogue, \"left\" if
within left-side dual dialogue, and nil otherwise."
  (save-excursion
    (save-match-data
      (save-restriction
        (widen)
        (when pos (goto-char pos))
        (cond ((progn (fountain-forward-character 0 'dialog)
                      (and (fountain-match-character)
                           (stringp (match-string 5))))
               'right)
              ((progn (fountain-forward-character 1 'dialog)
                      (and (fountain-match-character)
                           (stringp (match-string 5))))
               'left))))))



;;; Exporting

(defcustom fountain-export-profiles
  '(("afterwriting-usletter-doublespace"
     "afterwriting" "--pdf" "--overwrite"
     "--setting"
     "double_space_between_scenes=true"
     "--setting"
     "print_profile=usletter"
     "--source")
    ("afterwriting-a4-doublespace"
     "afterwriting" "--pdf" "--overwrite"
     "--setting"
     "double_space_between_scenes=true"
     "--setting"
     "print_profile=a4"
     "--source"))
  "Shell command profiles for exporting Fountain files.

Each profile takes the form:

    (PROFILE-NAME PROGRAM ARG ARG...)

Where PROFILE-NAME is an arbitrary profile name string, PROGRAM
is the program name string, and ARGs are the program argument
strings.

For each command `buffer-file-name' will be passed as last
program argument. The first profile is considered default.

n.b. If an ARG includes whitespace, this will be escaped and
passed to the program as a single argument. This is probably not
what you want, so these should be added as separate ARGs."
  :type '(repeat (cons :tag "Profile"
                       (string :tag "Profile Name")
                       (repeat :tag "Program Arguments"
                               (string :tag "Argument")))))

(defcustom fountain-export-buffer
  "*Fountain Export*"
  "Buffer name for `fountain-export-command' output."
  :type 'string)

(defun fountain-slugify (string)
  "Convert STRING to one suitable for slugs.

STRING is downcased, non-alphanumeric characters are removed, and
whitespace is converted to dashes. e.g.

    Hello Wayne's World 2! -> hello-wanyes-world-2"
  (save-match-data
    (string-join
     (split-string
      (downcase
       (replace-regexp-in-string "[^\n\s\t[:alnum:]]" "" string))
      "[^[:alnum:]]+" t)
     "-")))

(defun fountain-export (profile-name)
  "Call export shell command for PROFILE-NAME.
Export profiles are defined in `fountain-export-profiles'."
  (interactive
   (list (let ((default (caar fountain-export-profiles)))
           (completing-read (format "Export format [default %s]: " default)
                            (mapcar #'car fountain-export-profiles)
                            nil t nil nil default))))
  (unless profile-name
    (user-error "No `fountain-export-profiles' found"))
  (let ((profile (assoc-string profile-name fountain-export-profiles))
        program args)
    (setq program (cadr profile)
          args (cddr profile))
    (unless buffer-file-name
      (user-error "Buffer `%s' is not visiting a file" (current-buffer)))
    (apply 'start-process
           (append (list "fountain-export" fountain-export-buffer
                         program)
                   args (list buffer-file-name))))
  (pop-to-buffer fountain-export-buffer))


;;; Outlining

(require 'outline)

(defvar-local fountain--outline-cycle
  0
  "Internal local integer representing global outline cycling status.

    0: Show all
    1: Show level 1 section headings
    2: Show level 2 section headings
    3: Show level 3 section headings
    4: Show level 4 section headings
    5: Show level 5 section headings
    6: Show scene headings

Used by `fountain-outline-cycle'.")

(defvar-local fountain--outline-cycle-subtree
  0
  "Internal local integer representing subtree outline cycling status.

Used by `fountain-outline-cycle'.")

(defcustom fountain-outline-custom-level
  nil
  "Additional section headings to include in outline cycling."
  :type '(choice (const :tag "Only top-level" nil)
                 (const :tag "Level 2" 2)
                 (const :tag "Level 3" 3)
                 (const :tag "Level 4" 4)
                 (const :tag "Level 5" 5))
  :group 'fountain)

(defcustom fountain-shift-all-elements
  t
  "\\<fountain-mode-map>Non-nil if \\[fountain-shift-up] and \\[fountain-shift-down] should operate on all elements.
Otherwise, only operate on section and scene headings."
  :type 'boolean
  :safe 'boolean
  :group 'fountain)

(defcustom fountain-fold-notes
  t
  "\\<fountain-mode-map>If non-nil, fold contents of notes when cycling outline visibility.

Notes visibility can be cycled with \\[fountain-dwim]."
  :type 'boolean
  :safe 'boolean
  :group 'fountain)

(defalias 'fountain-outline-next 'outline-next-visible-heading)
(defalias 'fountain-outline-previous 'outline-previous-visible-heading)
(defalias 'fountain-outline-forward 'outline-forward-same-level)
(defalias 'fountain-outline-backward 'outline-backward-same-level)
(defalias 'fountain-outline-up 'outline-up-heading)
(defalias 'fountain-outline-mark 'outline-mark-subtree)
(defalias 'fountain-outline-show-all 'outline-show-all)

(when (< emacs-major-version 25)
  (defalias 'outline-show-all 'show-all)
  (defalias 'outline-show-entry 'show-entry)
  (defalias 'outline-show-subtree 'show-subtree)
  (defalias 'outline-show-children 'show-children)
  (defalias 'outline-hide-subtree 'hide-subtree)
  (defalias 'outline-hide-sublevels 'hide-sublevels))

(defun fountain-outline-invisible-p (&optional pos)
  "Non-nil if the character after POS has outline invisible property.
If POS is nil, use `point' instead."
  (eq (get-char-property (or pos (point)) 'invisible) 'outline))

(defun fountain-get-block-bounds ()
  "Return the beginning and end bounds of current element block."
  (let ((element (fountain-get-element))
        begin end)
    (when element
      (save-excursion
        (save-restriction
          (widen)
          (cond ((memq element '(section-heading scene-heading))
                 (setq begin (match-beginning 0))
                 (outline-end-of-subtree)
                 (skip-chars-forward "\n\s\t")
                 (setq end (point)))
                ((memq element '(character character-dd lines lines-dd paren paren-dd))
                 (fountain-forward-character 0)
                 (setq begin (line-beginning-position))
                 (while (not (or (eobp)
                                 (and (bolp) (eolp))
                                 (fountain-match-note)))
                   (forward-line))
                 (skip-chars-forward "\n\s\t")
                 (setq end (point)))
                ((memq element '(trans center synopsis note page-break))
                 (setq begin (match-beginning 0))
                 (goto-char (match-end 0))
                 (skip-chars-forward "\n\s\t")
                 (setq end (point)))
                ((eq element 'action)
                 (save-excursion
                   (if (fountain-blank-before-p)
                       (setq begin (line-beginning-position))
                     (backward-char)
                     (while (and (eq (fountain-get-element) 'action)
                                 (not (bobp)))
                       (forward-line -1))
                     (skip-chars-forward "\n\s\t")
                     (beginning-of-line)
                     (setq begin (point))))
                 (forward-line)
                 (unless (eobp)
                   (while (and (eq (fountain-get-element) 'action)
                               (not (eobp)))
                     (forward-line))
                   (skip-chars-forward "\n\s\t")
                   (beginning-of-line))
                 (setq end (point))))))
      (cons begin end))))

(defun fountain-insert-hanging-line-maybe ()
  "Insert a empty newline if needed.
Return non-nil if empty newline was inserted."
  (let (hanging-line)
    (when (and (eobp) (/= (char-before) ?\n))
      (insert "\n"))
    (when (and (eobp) (not (fountain-blank-before-p)))
      (insert "\n")
      (setq hanging-line t))
    (unless (eobp)
      (forward-char 1))
    hanging-line))

(defun fountain-shift-down (&optional n)
  "Move the current element down past N elements of the same level."
  (interactive "p")
  (unless n (setq n 1))
  (if (outline-on-heading-p)
      (fountain-outline-shift-down n)
    (when fountain-shift-all-elements
      (let ((forward (< 0 n))
            hanging-line)
        (when (and (bolp) (eolp))
          (funcall (if forward #'skip-chars-forward #'skip-chars-backward)
                   "\n\s\t"))
        (save-excursion
          (save-restriction
            (widen)
            (let ((block-bounds (fountain-get-block-bounds))
                  outline-begin outline-end next-block-bounds)
              (unless (and (car block-bounds)
                           (cdr block-bounds))
                (user-error "Not at a moveable element"))
              (save-excursion
                (when (not forward)
                  (goto-char (cdr block-bounds))
                  (when (setq hanging-line (fountain-insert-hanging-line-maybe))
                    (setcdr block-bounds (point)))
                  (goto-char (car block-bounds)))
                (outline-previous-heading)
                (setq outline-begin (point))
                (outline-next-heading)
                (setq outline-end (point)))
              (if forward
                  (goto-char (cdr block-bounds))
                (goto-char (car block-bounds))
                (backward-char)
                (skip-chars-backward "\n\s\t"))
              (setq next-block-bounds (fountain-get-block-bounds))
              (unless (and (car next-block-bounds)
                           (cdr next-block-bounds))
                (user-error "Cannot shift element any further"))
              (when forward
                (goto-char (cdr next-block-bounds))
                (when (setq hanging-line (fountain-insert-hanging-line-maybe))
                  (setcdr next-block-bounds (point))))
              (unless (< outline-begin (car next-block-bounds) outline-end)
                (user-error "Cannot shift past higher level"))
              (goto-char (if forward (car block-bounds) (cdr block-bounds)))
              (insert-before-markers
               (delete-and-extract-region (car next-block-bounds)
                                          (cdr next-block-bounds))))
            (when hanging-line
              (goto-char (point-max))
              (delete-char -1))))))))

(defun fountain-shift-up (&optional n)
  "Move the current element up past N elements of the same level."
  (interactive "p")
  (unless n (setq n 1))
  (fountain-shift-down (- n)))

(defun fountain-outline-shift-down (&optional n)
  "Move the current subtree down past N headings of same level."
  (interactive "p")
  (outline-back-to-heading)
  (let* (hanging-line
         (move-fun
          (if (< 0 n)
              'outline-get-next-sibling
            'outline-get-last-sibling))
         (end-point-fun
          (lambda ()
            (outline-end-of-subtree)
            (setq hanging-line (fountain-insert-hanging-line-maybe))
            (point)))
         (beg (point))
         (folded
          (save-match-data
            (outline-end-of-heading)
            (outline-invisible-p)))
         (end
          (save-match-data
            (funcall end-point-fun)))
         (insert-point (make-marker))
         (i (abs n)))
    (goto-char beg)
    (while (< 0 i)
      (or (funcall move-fun)
          (progn (goto-char beg)
                 (message "Cannot shift past higher level")))
      (setq i (1- i)))
    (when (< 0 n) (funcall end-point-fun))
    (set-marker insert-point (point))
    (insert (delete-and-extract-region beg end))
    (goto-char insert-point)
    (when folded (outline-hide-subtree))
    (when hanging-line
      (save-excursion
        (goto-char (point-max))
        (delete-char -1)))
    (set-marker insert-point nil)))

(defun fountain-outline-shift-up (&optional n)
  "Move the current subtree up past N headings of same level."
  (interactive "p")
  (fountain-outline-shift-down (- n)))

(defun fountain-outline-hide-level (n &optional silent)
  "Set outline visibilty to outline level N.
Display a message unless SILENT."
  (cond ((= n 0)
         (outline-show-all)
         (save-excursion
           (goto-char (point-min))
           (while (re-search-forward fountain-note-regexp nil 'move)
             (outline-flag-region (match-beginning 1)
                                  (match-end 1) fountain-fold-notes)))
         (unless silent (message "Showing all")))
        ((= n 6)
         (outline-hide-sublevels n)
         (unless silent (message "Showing scene headings")))
        (t
         (outline-hide-sublevels n)
         (unless silent (message "Showing level %s headings" n))))
  (setq fountain--outline-cycle n))

(defun fountain-outline-hide-custom-level ()
  "Set the outline visibilty to `fountain-outline-custom-level'."
  (when fountain-outline-custom-level
    (fountain-outline-hide-level fountain-outline-custom-level t)))

;; FIXME: document
(defun fountain-outline-cycle (&optional arg)
  "\\<fountain-mode-map>Cycle outline visibility depending on ARG.

    1. If ARG is nil, cycle outline visibility of current subtree and
       its children (\\[fountain-dwim]).
    2. If ARG is 4, cycle outline visibility of buffer (\\[universal-argument] \\[fountain-dwim],
       same as \\[fountain-outline-cycle-global]).
    3. If ARG is 16, show all (\\[universal-argument] \\[universal-argument] \\[fountain-dwim]).
    4. If ARG is 64, show outline visibility set in
       `fountain-outline-custom-level' (\\[universal-argument] \\[universal-argument] \\[universal-argument] \\[fountain-dwim])."
  (interactive "p")
  (let ((custom-level
         (when fountain-outline-custom-level
           (save-excursion
             (goto-char (point-min))
             (let (found)
               (while (and (not found)
                           (outline-next-heading))
                 (when (= (funcall outline-level) fountain-outline-custom-level)
                   (setq found t)))
               (when found fountain-outline-custom-level)))))
        (highest-level
         (save-excursion
           (goto-char (point-max))
           (outline-back-to-heading t)
           (let ((level (funcall outline-level)))
             (while (and (not (bobp))
                         (< 1 level))
               (outline-up-heading 1 t)
               (unless (bobp)
                 (setq level (funcall outline-level))))
             level)))
        (fold-notes-fun
         (lambda (eohp eosp)
           (goto-char eohp)
           (while (re-search-forward fountain-note-regexp eosp 'move)
             (outline-flag-region (match-beginning 1)
                                  (match-end 1) fountain-fold-notes)))))
    (cond ((eq arg 4)
           (cond
            ((and (= fountain--outline-cycle 1) custom-level)
             (fountain-outline-hide-level custom-level))
            ((< 0 fountain--outline-cycle 6)
             (fountain-outline-hide-level 6))
            ((= fountain--outline-cycle 6)
             (fountain-outline-hide-level 0))
            ((= highest-level 6)
             (fountain-outline-hide-level 6))
            (t
             (fountain-outline-hide-level highest-level))))
          ((eq arg 16)
           (outline-show-all)
           (message "Showing all")
           (setq fountain--outline-cycle 0))
          ((eq arg 64)
           (if custom-level
               (fountain-outline-hide-level custom-level)
             (outline-show-all)))
          (t
           (save-excursion
             (outline-back-to-heading)
             (let ((eohp
                    (save-excursion
                      (outline-end-of-heading)
                      (point)))
                   (eosp
                    (save-excursion
                      (outline-end-of-subtree)
                      (point)))
                   (eolp
                    (save-excursion
                      (forward-line)
                      (while (and (not (eobp))
                                  (get-char-property (1- (point)) 'invisible))
                        (forward-line))
                      (point)))
                   (children
                    (save-excursion
                      (outline-back-to-heading)
                      (let ((level (funcall outline-level)))
                        (outline-next-heading)
                        (and (outline-on-heading-p t)
                             (< level (funcall outline-level)))))))
               (cond
                ((= eosp eohp)
                 (message "Empty heading")
                 (setq fountain--outline-cycle-subtree 0))
                ((and (<= eosp eolp)
                      children)
                 (outline-show-entry)
                 (outline-show-children)
                 (funcall fold-notes-fun eohp eosp)
                 (message "Showing headings")
                 (setq fountain--outline-cycle-subtree 2))
                ((or (<= eosp eolp)
                     (= fountain--outline-cycle-subtree 2))
                 (outline-show-subtree)
                 (goto-char eohp)
                 (funcall fold-notes-fun eohp eosp)
                 (message "Showing contents")
                 (setq fountain--outline-cycle-subtree 3))
                (t
                 (outline-hide-subtree)
                 (message "Hiding contents")
                 (setq fountain--outline-cycle-subtree 1)))))))))

(defun fountain-outline-cycle-global ()
  "Globally cycle outline visibility.

Calls `fountain-outline-cycle' with argument 4 to cycle buffer
outline visibility through the following states:

    1. Top-level section headings
    2. Value of `fountain-outline-custom-level'
    3. All section headings and scene headings
    4. Everything"
  (interactive)
  (fountain-outline-cycle 4))

(defun fountain-outline-level ()
  "Return the heading's nesting level in the outline.
Assumes that point is at the beginning of a heading and match
data reflects `outline-regexp'."
  (if (string-prefix-p "#" (match-string 0))
      (string-width (match-string 1))
    6))

(defun fountain-insert-section-heading ()
  "Insert an empty section heading at the current outline level."
  (interactive)
  (unless (and (bolp) (eolp))
    (if (bolp)
        (save-excursion (newline))
      (end-of-line) (newline)))
  (let (level)
    (save-excursion
      (save-restriction
        (widen)
        (ignore-errors
          (outline-back-to-heading t)
          (if (= (funcall outline-level) 6)
              (outline-up-heading 1)))
        (setq level
              (if (outline-on-heading-p)
                  (funcall outline-level)
                1))))
    (insert (make-string level ?#) " ")))

(defcustom fountain-pop-up-indirect-windows
  nil
  "Non-nil if opening indirect buffers should make a new window."
  :type 'boolean
  :group 'fountain)

(defun fountain-outline-to-indirect-buffer ()
  "Clone section/scene at point to indirect buffer.

Set `fountain-pop-up-indirect-windows' to control how indirect
buffer windows are opened."
  (interactive)
  (let ((pop-up-windows fountain-pop-up-indirect-windows)
        (base-buffer (buffer-name (buffer-base-buffer)))
        beg end heading-name target-buffer)
    (save-excursion
      (save-restriction
        (widen)
        (outline-back-to-heading t)
        (setq beg (point))
        (when (or (fountain-match-section-heading)
                  (fountain-match-scene-heading))
          (setq heading-name (match-string-no-properties 2)
                target-buffer (concat base-buffer "-" heading-name))
          (outline-end-of-subtree)
          (setq end (point)))))
    (if (and (get-buffer target-buffer)
             (with-current-buffer target-buffer
               (goto-char beg)
               (and (or (fountain-match-section-heading)
                        (fountain-match-scene-heading))
                    (string= heading-name (match-string-no-properties 2)))))
        (pop-to-buffer target-buffer)
      (clone-indirect-buffer target-buffer t)
      (outline-show-all))
    (narrow-to-region beg end)))


;;; Navigation

(defun fountain-forward-scene (&optional n)
  "Move forward N scene headings (backward if N is negative).
If N is 0, move to beginning of scene."
  (interactive "^p")
  (unless n (setq n 1))
  (let* ((p (if (<= n 0) -1 1))
         (move-fun
          (lambda ()
            (while (not (or (eq (point) (buffer-end p))
                            (fountain-match-scene-heading)))
              (forward-line p)))))
    (if (/= n 0)
        (while (/= n 0)
          (when (fountain-match-scene-heading) (forward-line p))
          (funcall move-fun)
          (setq n (- n p)))
      (beginning-of-line)
      (funcall move-fun))))

(defun fountain-backward-scene (&optional n)
  "Move backward N scene headings (foward if N is negative)."
  (interactive "^p")
  (unless n (setq n 1))
  (fountain-forward-scene (- n)))

;; FIXME: needed?
(defun fountain-beginning-of-scene ()
  "Move point to beginning of current scene."
  (interactive "^")
  (fountain-forward-scene 0))

;; FIXME: needed?
(defun fountain-end-of-scene ()
  "Move point to end of current scene."
  (interactive "^")
  (fountain-forward-scene 1)
  (unless (eobp)
    (backward-char)))

;; FIXME: extending region
(defun fountain-mark-scene ()
  "Put mark at end of this scene, point at beginning."
  (interactive)
  ;; (if (or extend
  ;;         (and (region-active-p)
  ;;              (eq last-command this-command)))
  ;;     (progn
  ;;       (fountain-forward-scene 1)
  ;;       (push-mark)
  ;;       (exchange-point-and-mark))
  (push-mark)
  (fountain-forward-scene 0)
  (if (not (or (fountain-match-section-heading)
               (fountain-match-scene-heading)))
      (progn
        (goto-char (mark))
        (user-error "Before first scene heading"))
    (push-mark)
    (fountain-forward-scene 1)
    (exchange-point-and-mark)))

(defun fountain-goto-scene (n)
  "Move point to Nth scene in current buffer.

Ignores revised scene numbers scenes.

    10  = 10
    10B = 10
    A10 =  9"
  (interactive "NGo to scene: ")
  (push-mark)
  (goto-char (point-min))
  (let ((scene (if (fountain-match-scene-heading)
                   (car (fountain-scene-number-to-list (match-string 8)))
                 0)))
    (while (and (< scene n)
                (< (point) (point-max)))
      (fountain-forward-scene 1)
      (when (fountain-match-scene-heading)
        (setq scene (or (car (fountain-scene-number-to-list (match-string 8)))
                        (1+ scene)))))))

(defun fountain-goto-page (n)
  "Move point to Nth appropropriate page in current buffer."
  (interactive "NGo to page: ")
  (widen)
  (push-mark)
  (goto-char (point-min))
  (let ((i n)
        (export-elements (fountain-get-export-elements)))
    (while (fountain-match-metadata) (forward-line))
    (if (looking-at "[\n\s\t]*\n") (goto-char (match-end 0)))
    (while (< 1 i)
      (if (and (fountain-match-page-break) (match-string 2))
          (setq i (- n (string-to-number (match-string 2)))))
      (fountain-forward-page export-elements)
      (setq i (1- i)))))

(defun fountain-forward-character (&optional n limit)
  "Goto Nth next character (or Nth previous is N is negative).
If LIMIT is 'dialog, halt at end of dialog. If LIMIT is 'scene,
halt at end of scene."
  (interactive "^p")
  (unless n (setq n 1))
  (let* ((p (if (<= n 0) -1 1))
         (move-fun
          (lambda ()
            (while (cond ((eq limit 'dialog)
                          (and (not (= (point) (buffer-end p)))
                               (or (and (bolp) (eolp))
                                   (fountain-match-dialog)
                                   (fountain-match-paren))))
                         ((eq limit 'scene)
                          (not (or (= (point) (buffer-end p))
                                   (fountain-match-character)
                                   (fountain-match-scene-heading))))
                         ((not (or (= (point) (buffer-end p))
                                   (fountain-match-character)))))
              (forward-line p)))))
    (if (/= n 0)
        (while (/= n 0)
          (when (fountain-match-character) (forward-line p))
          (funcall move-fun)
          (setq n (- n p)))
      (beginning-of-line)
      (funcall move-fun))))

(defun fountain-backward-character (&optional n)
  "Move backward N character (foward if N is negative)."
  (interactive "^p")
  (unless n (setq n 1))
  (fountain-forward-character (- n)))


;;; Editing

(defcustom fountain-auto-upcase-scene-headings
  t
  "If non-nil, automatically upcase lines matching `fountain-scene-heading-regexp'."
  :type 'boolean
  :group 'fountain)

(defun fountain-auto-upcase ()
  "Upcase all or part of the current line contextually.

If `fountain-auto-upcase-scene-headings' is non-nil and point is
at a scene heading, activate auto upcasing for beginning of line
to scene number or point."
  (when (and fountain-auto-upcase-scene-headings
             (fountain-match-scene-heading))
    (upcase-region (line-beginning-position) (or (match-end 2) (point)))))

(defun fountain-dwim (&optional arg)
  "Call a command based on context (Do What I Mean).

1. If prefixed with ARG, call `fountain-outline-cycle' and pass
   ARG.

2. If point is at an appropriate point (i.e. eolp), call
   `completion-at-point'.

3. If point is a scene heading or section heading call
   `fountain-outline-cycle'. "
  (interactive "p")
  (cond ((and arg (< 1 arg))
         (fountain-outline-cycle arg))
        ((fountain-match-note)
         (outline-flag-region (match-beginning 1)
                              (match-end 1)
           (not (get-char-property (match-beginning 1) 'invisible))))
        ((eolp)
         (completion-at-point))
        ((or (fountain-match-section-heading)
             (fountain-match-scene-heading)
             (eq (get-char-property (point) 'invisible) 'outline))
         (fountain-outline-cycle))))

(defun fountain-upcase-line (&optional arg)
  "Upcase the line.
If prefixed with ARG, insert `.' at beginning of line to force
a scene heading."
  (interactive "P")
  (when arg (save-excursion (beginning-of-line) (insert ".")))
  (upcase-region (line-beginning-position) (line-end-position)))

(defun fountain-upcase-line-and-newline (&optional arg)
  "Upcase the line and insert a newline.
If prefixed with ARG, insert `.' at beginning of line to force
a scene heading."
  (interactive "P")
  (when (and arg (not (fountain-match-scene-heading)))
    (save-excursion
      (beginning-of-line)
      (insert ".")))
  (upcase-region (line-beginning-position) (point))
  (insert "\n"))

(defun fountain-delete-comments-in-region (start end)
  "Delete comments in region between START and END."
  (save-excursion
    (goto-char end)
    (setq end (point-marker))
    (goto-char start)
    (while (< (point) end)
      (let ((x (point)))
        (if (forward-comment 1)
            (delete-region x (point))
          (unless (eobp) (forward-char 1)))))
    (set-marker end nil)))

(defun fountain-insert-synopsis ()
  "Insert synopsis below scene heading of current scene."
  (interactive)
  (widen)
  (when (outline-back-to-heading)
    (forward-line)
    (or (bolp) (newline))
    (unless (and (bolp) (eolp)
                 (fountain-blank-after-p))
      (save-excursion
        (newline)))
    (insert "= ")
    (when (outline-invisible-p) (fountain-outline-cycle))))

(defun fountain-insert-note (&optional arg)
  "Insert a note based on `fountain-note-template' underneath current element.
If region is active and it is appropriate to act on, only
surround region with note delimiters (`[[ ]]'). If prefixed with
ARG (\\[universal-argument]), only insert note delimiters."
  (interactive "P")
  (let ((comment-start "[[")
        (comment-end "]]"))
    (if (or arg (use-region-p))
        (comment-dwim nil)
      (unless (and (bolp) (eolp))
        (re-search-forward "^[\s\t]*$" nil 'move))
      (unless (fountain-blank-after-p)
        (save-excursion
          (newline)))
      (comment-indent)
      (insert
       (replace-regexp-in-string
        fountain-template-regexp
        (lambda (match)
          (let ((key (match-string 1 match)))
            (cdr
             ;; FIXME: rather than hard-code limited options, these
             ;; could work better if reusing the key-value replacement
             ;; code from `fountain-export-element'.
             (assoc-string key (list (cons 'title (file-name-base (buffer-name)))
                                     (cons 'time (format-time-string fountain-time-format))
                                     (cons 'fullname user-full-name)
                                     (cons 'nick (capitalize user-login-name))
                                     (cons 'email user-mail-address))))))
        fountain-note-template)))))

(define-obsolete-function-alias 'fountain-continued-dialog-refresh
  'fountain-contd-dialog-refresh "3.0.0")
(defun fountain-contd-dialog-refresh ()
  "Add or remove continued dialog in buffer.

If `fountain-add-contd-dialog' is non-nil, add
`fountain-contd-dialog-string' on characters speaking in
succession, otherwise remove all occurences.

If `fountain-contd-dialog-string' has changed, also attempt
to remove previous string first."
  (interactive)
  (save-excursion
    (save-restriction
      (widen)
      (let ((job (make-progress-reporter "Refreshing continued dialog..."))
            (backup (car (get 'fountain-contd-dialog-string
                              'backup-value)))
            (replace-fun
             (lambda (string job)
               (goto-char (point-min))
               (unless (fountain-match-character)
                 (fountain-forward-character))
               (while (< (point) (point-max))
                 (if (re-search-forward
                      (concat "[\s\t]*" string) (line-end-position) t)
                     (delete-region (match-beginning 0) (match-end 0)))
                 (fountain-forward-character)
                 (progress-reporter-update job))))
            case-fold-search)
        (when (string= fountain-contd-dialog-string backup)
          (setq backup (eval (car (get 'fountain-contd-dialog-string
                                       'standard-value))
                             t)))
        ;; Delete all matches of backup string.
        (when (stringp backup) (funcall replace-fun backup job))
        ;; Delete all matches of current string.
        (funcall replace-fun fountain-contd-dialog-string job)
        ;; When `fountain-add-contd-dialog', add string where
        ;; appropriate.
        (when fountain-add-contd-dialog
          (goto-char (point-min))
          (while (< (point) (point-max))
            (when (and (not (looking-at-p
                             (concat ".*" fountain-contd-dialog-string "$")))
                       (fountain-match-character)
                       (string= (fountain-get-character 0)
                                (fountain-get-character -1 'scene)))
              (re-search-forward "\s*$" (line-end-position) t)
              (replace-match fountain-contd-dialog-string))
            (forward-line)
            (progress-reporter-update job)))
        (progress-reporter-done job)))))


;;; Scene Numbers

(defgroup fountain-scene-numbers ()
  "Options for scene numbers."
  :prefix "fountain-scene-numbers-"
  :group 'fountain)

(define-obsolete-variable-alias   'fountain-display-scene-numbers-in-margin
  'fountain-scene-numbers-display-in-margin "3.0.0")
(defcustom fountain-scene-numbers-display-in-margin
  nil
  "If non-nil, display scene numbers in the right margin.

If nil, do not change scene number display.

This option does affect file contents."
  :group 'fountain-scene-numbers
  :type 'boolean
  :safe 'booleanp
  :set #'fountain--set-and-refresh-all-font-lock)

(define-obsolete-variable-alias 'fountain-prefix-revised-scene-numbers
  'fountain-scene-numbers-prefix-revised "3.0.0")
(defcustom fountain-scene-numbers-prefix-revised
  nil
  "If non-nil, revised scene numbers are prefixed.

If nil, when inserting new scene headings after numbering
existing scene headings, revised scene number format works as
follows:

    10
    10A <- new scene
    11

If non-nil, revised scene number format works as follows:

    10
    A11 <- new scene
    11

WARNING: Using conflicting revised scene number format in the
same script may result in errors in output."
  :type 'boolean
  :safe 'booleanp
  :group 'fountain-scene-numbers)

(define-obsolete-variable-alias 'fountain-scene-number-first-revision
  'fountain-scene-numbers-first-revision-char "3.0.0")
(defcustom fountain-scene-numbers-first-revision-char
  ?A
  "Character to start revised scene numbers."
  :type 'character
  :safe 'characterp
  :group 'fountain-scene-numbers)

(define-obsolete-variable-alias 'fountain-scene-number-separator
  'fountain-scene-numbers-separator "3.0.0")
(defcustom fountain-scene-numbers-separator
  nil
  "Character to separate scene numbers."
  :type '(choice (const nil)
                 (character ?-))
  :safe '(lambda (value)
           (or (null value)
               (characterp value)))
  :group 'fountain-scene-numbers)

(defun fountain-scene-number-to-list (string)
  "Read scene number STRING and return a list.

If `fountain-scene-numbers-prefix-revised' is non-nil:

    \"10\" -> (10)
    \"AA10\" -> (9 1 1)

Or if nil:

    \"10\" -> (10)
    \"10AA\" -> (10 1 1)"
  ;; FIXME: does not account for user option
  ;; `fountain-scene-numbers-separator' or
  ;; `fountain-scene-numbers-first-revision-char'.
  (let (number revision)
    (when (stringp string)
      (if fountain-scene-numbers-prefix-revised
          (when (string-match "\\([a-z]*\\)[\\.-]*\\([0-9]+\\)[\\.-]*" string)
            (setq number (string-to-number (match-string 2 string))
                  revision (match-string 1 string))
            (unless (string-empty-p revision) (setq number (1- number))))
        (when (string-match "\\([0-9]+\\)[\\.-]*\\([a-z]*\\)[\\.-]*" string)
          (setq number (string-to-number (match-string-no-properties 1 string))
                revision (match-string-no-properties 2 string))))
      (setq revision (mapcar (lambda (n) (- (upcase n) 64)) revision))
      (cons number revision))))

(defun fountain-scene-number-to-string (scene-num-list)
  "Read scene number SCENE-NUM-LIST and return a string.

If `fountain-scene-numbers-prefix-revised' is non-nil:

    (10) -> \"10\"
    (9 1 2) -> \"AB10\"

Or, if nil:

    (10) -> \"10\"
    (9 1 2) -> \"9AB\""
  (let ((number (car scene-num-list))
        separator revision)
    (when (< 1 (length scene-num-list))
      (setq separator
            (if fountain-scene-numbers-separator
                (char-to-string fountain-scene-numbers-separator)
              "")
            revision
            (mapconcat (lambda (char)
                         (char-to-string
                          (+ (1- char) fountain-scene-numbers-first-revision-char)))
                       (cdr scene-num-list) separator)))
    (if fountain-scene-numbers-prefix-revised
        (progn
          (unless (string-empty-p revision) (setq number (1+ number)))
          (concat revision separator (number-to-string number)))
      (concat (number-to-string number) separator revision))))

(defun fountain-get-scene-number (&optional n)
  "Return the scene number of the Nth next scene as a list.
Return Nth previous if N is negative.

Scene numbers will not be accurate if buffer contains directives
to include external files."
  (unless n (setq n 0))
  ;; FIXME: the whole scene number (and page number) logic could be
  ;; improved by first generating a list of existing numbers,
  ;; e.g. '((4) (5) (5 1) (6))
  ;; then only calculating revised scene when current = next.
  (save-excursion
    (save-restriction
      (widen)
      ;; Make sure we're at a scene heading.
      (fountain-forward-scene 0)
      ;; Go to the Nth scene.
      (unless (= n 0) (fountain-forward-scene n))
      ;; Unless we're at a scene heading now, raise a user error.
      (unless (fountain-match-scene-heading)
        (user-error "Before first scene heading"))
      (let ((x (point))
            ;; FIXME: scenes should never be treated as out of order.
            (err-order "Scene `%s' seems to be out of order")
            found)
        ;; First, check if there are any scene numbers already. If not
        ;; we can save a lot of work.
        ;; FIXME: this is just extra work since we're doing for each
        ;; scene heading
        (save-match-data
          (goto-char (point-min))
          (while (not (or found (eobp)))
            (when (and (re-search-forward fountain-scene-heading-regexp nil 'move)
                       (match-string 9))
              (setq found t))))
        (if found
            ;; There are scene numbers, so this scene number needs to be
            ;; calculated relative to those.
            (let ((current-scene (fountain-scene-number-to-list (match-string 9)))
                  last-scene next-scene)
              ;; Check if scene heading is already numbered and if there
              ;; is a NEXT-SCENE. No previousscene number can be greater
              ;; or equal to this.
              (goto-char x)
              (while (not (or next-scene (eobp)))
                (fountain-forward-scene 1)
                (when (fountain-match-scene-heading)
                  (setq next-scene (fountain-scene-number-to-list (match-string 9)))))
              (cond
               ;; If there's both a NEXT-SCENE and CURRENT-SCENE, but
               ;; NEXT-SCENE is less or equal to CURRENT-SCENE, scene
               ;; numbers are out of order.
               ((and current-scene next-scene
                     (version-list-<= next-scene current-scene))
                (user-error err-order (fountain-scene-number-to-string current-scene)))
               ;; Otherwise, if there is a CURRENT-SCENE and either no
               ;; NEXT-SCENE or there is and it's greater then
               ;; CURRENT-SCENE, just return CURRENT-SCENE.
               (current-scene)
               (t
                ;; There is no CURRENT-SCENE yet, so go to the first
                ;; scene heading and if it's already numberd set it to
                ;; that, or just (list 1).
                (goto-char (point-min))
                (unless (fountain-match-scene-heading)
                  (fountain-forward-scene 1))
                (when (<= (point) x)
                  (setq current-scene
                        (or (fountain-scene-number-to-list (match-string 9))
                            (list 1))))
                ;; While before point X, go forward through each scene
                ;; heading, setting LAST-SCENE to CURRENT-SCENE and
                ;; CURRENT-SCENE to an incement of (car LAST-SCENE).
                (while (< (point) x (point-max))
                  (fountain-forward-scene 1)
                  (when (fountain-match-scene-heading)
                    (setq last-scene current-scene
                          current-scene (or (fountain-scene-number-to-list (match-string 9))
                                            (list (1+ (car last-scene)))))
                    ;; However, this might make CURRENT-SCENE greater or
                    ;; equal to NEXT-SCENE (a problem), so if there is a
                    ;; NEXT-SCENE, and NEXT-SCENE is less or equal to
                    ;; CURRENT-SCENE:
                    ;;
                    ;; 1. pop (car LAST-SCENE), which should always be
                    ;;    less than NEXT-SCENE as N
                    ;; 2. set CURRENT-SCENE to (list TMP-SCENE (1+ N))
                    ;; 3. set TMP-SCENE to (list TMP-SCENE n)
                    ;;
                    ;; Loop through this so that the last (or only)
                    ;; element of CURRENT-SCENE is incremented by 1, and
                    ;; TMP-SCENE is appended with N or 1. e.g.
                    ;;
                    ;; CURRENT-SCENE (4 2) -> (4 3)
                    ;; TMP-SCENE (4 2) -> (4 2 1)
                    ;;
                    ;; Return CURRENT-SCENE.
                    (let (n tmp-scene)
                      (while (and next-scene (version-list-<= next-scene current-scene))
                        (setq n (pop last-scene)
                              current-scene (append tmp-scene (list (1+ (or n 0))))
                              tmp-scene (append tmp-scene (list (or n 1))))
                        (when (version-list-<= next-scene tmp-scene)
                          (user-error err-order
                                      (fountain-scene-number-to-string current-scene)))))))
                current-scene)))
          ;; Otherwise there were no scene numbers, so we can just count
          ;; the scenes.
          (goto-char (point-min))
          (unless (fountain-match-scene-heading)
            (fountain-forward-scene 1))
          (let ((current-scene 1))
            (while (< (point) x)
              (fountain-forward-scene 1)
              (when (fountain-match-scene-heading)
                (setq current-scene (1+ current-scene))))
            (list current-scene)))))))

(defun fountain-remove-scene-numbers ()
  "Remove scene numbers from scene headings in current buffer."
  (interactive)
  (save-excursion
    (save-restriction
      (widen)
      (let (buffer-invisibility-spec)
        (goto-char (point-min))
        (unless (fountain-match-scene-heading)
          (fountain-forward-scene 1))
        (while (and (fountain-match-scene-heading)
                    (< (point) (point-max)))
          (when (match-string 8)
            (delete-region (match-beginning 6) (match-end 9)))
          (fountain-forward-scene 1))))))

(defun fountain-add-scene-numbers ()
  "Add scene numbers to scene headings in current buffer.

Adding scene numbers to scene headings after numbering existing
scene headings will use a prefix or suffix letter, depending on
the value of `fountain-scene-numbers-prefix-revised':

    10
    10A <- new scene
    10B <- new scene
    11

If further scene headings are inserted:

    10
    10A
    10AA <- new scene
    10B
    11

In this example, you can't automatically number a new scene
between 10 and 10A (which might be numbered as 10aA). Instead,
add these scene numbers manually. Note that if
`fountain-auto-upcase-scene-headings' is non-nil you will need to
insert the scene number delimiters (\"##\") first, to protect the
scene number from being auto-upcased."
  (interactive)
  (save-excursion
    (save-restriction
      (widen)
      (let ((job (make-progress-reporter "Adding scene numbers..."))
            buffer-invisibility-spec)
        (goto-char (point-min))
        (unless (fountain-match-scene-heading)
          (fountain-forward-scene 1))
        (while (and (fountain-match-scene-heading)
                    (< (point) (point-max)))
          (unless (match-string 8)
            (end-of-line)
            (delete-horizontal-space t)
            (insert "\s#" (fountain-scene-number-to-string (fountain-get-scene-number)) "#"))
          (fountain-forward-scene 1)
          (progress-reporter-update job))
        (progress-reporter-done job)))))


;;; Font Lock

(defun fountain-get-font-lock-decoration ()
  "Return the value of `font-lock-maximum-decoration' for `fountain-mode'."
  (let ((n (if (listp font-lock-maximum-decoration)
               (cdr (or (assq 'fountain-mode font-lock-maximum-decoration)
                        (assq 't font-lock-maximum-decoration)))
             font-lock-maximum-decoration)))
    (cond ((null n) 2)
          ((eq n t) 3)
          ((integerp n) n)
          (t 2))))

(defun fountain-set-font-lock-decoration (n)
  "Set `font-lock-maximum-decoration' for `fountain-mode' to N."
  (interactive
   (list (or current-prefix-arg
             (string-to-number (char-to-string
               (read-char-choice "Maximum decoration (1-3): "
                                 '(?1 ?2 ?3)))))))
  (if (and (integerp n)
           (<= 1 n 3))
      (let ((level (cond ((= n 1) 1)
                         ((= n 2) nil)
                         ((= n 3) t))))
        (cond ((listp font-lock-maximum-decoration)
               (setq font-lock-maximum-decoration
                     (assq-delete-all 'fountain-mode font-lock-maximum-decoration))
               (customize-set-variable 'font-lock-maximum-decoration
                                       (cons (cons 'fountain-mode level)
                                             font-lock-maximum-decoration)))
              ((or (booleanp font-lock-maximum-decoration)
                   (integerp font-lock-maximum-decoration))
               (customize-set-variable 'font-lock-maximum-decoration
                                       (list (cons 'fountain-mode level)
                                             (cons 't font-lock-maximum-decoration)))))
        (message "Syntax highlighting is now: %s"
                 (cond ((= n 1) "minimum")
                       ((= n 2) "default")
                       ((= n 3) "maximum")))
        (font-lock-refresh-defaults))
    (user-error "Decoration must be an integer 1-3")))

(defun fountain-init-font-lock ()
  "Return a new list of `font-lock-mode' keywords for elements."
  (let ((dec (fountain-get-font-lock-decoration))
        keywords)
    (dolist (element fountain-element-list keywords)
      (let ((matcher (eval (plist-get (cdr element) :matcher)))
            (align (eval (plist-get (cdr element) :align)))
            subexp-highlighter)
        (when (and align fountain-align-elements)
          (unless (integerp align)
            (setq align
                  (cadr (or (assoc (or (plist-get (fountain-read-metadata)
                                                  'format)
                                       fountain-default-script-format)
                                   align)
                            (car align))))))
        (dolist (hl (plist-get (cdr element) :highlight))
          (let* ((subexp (nth 1 hl))
                 (face (when (<= (nth 0 hl) dec) (nth 2 hl)))
                 (invisible (when (nth 5 hl) (list 'invisible (nth 5 hl))))
                 (align-spec (when (integerp align)
                               (list
                                'line-prefix (list 'space :align-to align)
                                'wrap-prefix (list 'space :align-to align))))
                 (override (nth 3 hl))
                 (laxmatch (nth 4 hl)))
            (setq subexp-highlighter
                  (append subexp-highlighter
                          (list (list subexp
                        (list 'quote (append (list 'face face)
                                             invisible align-spec))
                        override laxmatch))))))
        (setq keywords
              (append keywords
                      (list (cons matcher subexp-highlighter))))))))

(defun fountain-redisplay-scene-numbers (start end)
  "Apply display text properties to scene numbers between START and END.

If `fountain-scene-numbers-display-in-margin' is non-nil and
scene heading has scene number, apply display text properties to
redisplay in margin. Otherwise, remove display text properties."
  ;; FIXME: Why use jit-lock rather than font-lock?
  (goto-char start)
  (while (< (point) (min end (point-max)))
    (when (fountain-match-scene-heading)
      (if (and fountain-scene-numbers-display-in-margin
               (match-string 9))
          (put-text-property (match-beginning 7) (match-end 10)
                             'display (list '(margin right-margin)
                                            (match-string-no-properties 9)))
        (remove-text-properties (match-beginning 0) (match-end 0)
                                '(display))))
    (forward-line)))


;;; Key Bindings

(defvar fountain-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Editing commands:
    (define-key map (kbd "TAB") #'fountain-dwim)
    (define-key map (kbd "C-c RET") #'fountain-upcase-line-and-newline)
    (define-key map (kbd "<S-return>") #'fountain-upcase-line-and-newline)
    (define-key map (kbd "C-c C-c") #'fountain-upcase-line)
    (define-key map (kbd "C-c C-d") #'fountain-contd-dialog-refresh)
    (define-key map (kbd "C-c C-z") #'fountain-insert-note)
    (define-key map (kbd "C-c C-a") #'fountain-insert-synopsis)
    (define-key map (kbd "C-c C-x i") #'auto-insert)
    (define-key map (kbd "C-c C-x #") #'fountain-add-scene-numbers)
    (define-key map (kbd "C-c C-x _") #'fountain-remove-scene-numbers)
    (define-key map (kbd "C-c C-x f") #'fountain-set-font-lock-decoration)
    (define-key map (kbd "C-c C-x RET") #'fountain-insert-page-break)
    (define-key map (kbd "M-TAB") #'completion-at-point)
    (define-key map (kbd "C-c C-x a") #'fountain-completion-update)
    ;; Navigation commands:
    (define-key map [remap beginning-of-defun] #'fountain-beginning-of-scene)
    (define-key map [remap end-of-defun] #'fountain-end-of-scene)
    (define-key map (kbd "M-g s") #'fountain-goto-scene)
    (define-key map (kbd "M-g p") #'fountain-goto-page)
    (define-key map (kbd "M-n") #'fountain-forward-character)
    (define-key map (kbd "M-p") #'fountain-backward-character)
    ;; Block editing commands:
    (define-key map (kbd "<M-down>") #'fountain-shift-down)
    (define-key map (kbd "ESC <down>") #'fountain-shift-down)
    (define-key map (kbd "<M-up>") #'fountain-shift-up)
    (define-key map (kbd "ESC <up>") #'fountain-shift-up)
    ;; Outline commands:
    (define-key map [remap forward-list] #'fountain-outline-next)
    (define-key map [remap backward-list] #'fountain-outline-previous)
    (define-key map [remap forward-sexp] #'fountain-outline-forward)
    (define-key map [remap backward-sexp] #'fountain-outline-backward)
    (define-key map [remap backward-up-list] #'fountain-outline-up)
    (define-key map [remap mark-defun] #'fountain-outline-mark)
    (define-key map (kbd "C-c TAB") #'fountain-outline-cycle)
    (define-key map (kbd "<backtab>") #'fountain-outline-cycle-global)
    (define-key map (kbd "S-TAB") #'fountain-outline-cycle-global)
    (define-key map (kbd "M-RET") #'fountain-insert-section-heading)
    (define-key map (kbd "C-c C-x b") #'fountain-outline-to-indirect-buffer)
    ;; Pages
    (define-key map (kbd "C-c C-x p") #'fountain-count-pages)
    ;; Exporting commands:
    (define-key map (kbd "C-c C-e") #'fountain-export)
    map)
  "Mode map for `fountain-mode'.")


;;; Menu

(require 'easymenu)

(easy-menu-define fountain-mode-menu fountain-mode-map
  "Menu for `fountain-mode'."
  '("Fountain"
    ("Navigate"
     ["Next Heading" fountain-outline-next]
     ["Previous Heading" fountain-outline-previous]
     ["Up Heading" fountain-outline-up]
     ["Forward Heading Same Level" fountain-outline-forward]
     ["Backward Heading Same Level" fountain-outline-backward]
     "---"
     ["Cycle Outline Visibility" fountain-outline-cycle]
     ["Cycle Global Outline Visibility" fountain-outline-cycle-global]
     ["Show All" fountain-outline-show-all]
     "---"
     ["Next Character" fountain-forward-character]
     ["Previous Character" fountain-backward-character]
     "---"
     ["Go to Scene Heading..." fountain-goto-scene]
     ["Go to Page..." fountain-goto-page])
    ("Edit Structure"
     ["Insert Section Heading" fountain-insert-section-heading]
     ["Mark Subtree" fountain-outline-mark]
     ["Open Subtree in Indirect Buffer" fountain-outline-to-indirect-buffer]
     "---"
     ["Shift Element Up" fountain-shift-up]
     ["Shift Element Down" fountain-shift-down]
     "---"
     ["Shift All Elements" (customize-set-variable 'fountain-shift-all-elements
                                             (not fountain-shift-all-elements))
      :style toggle
      :selected fountain-shift-all-elements])
    ("Scene Numbers"
     ["Add Scene Numbers" fountain-add-scene-numbers]
     ["Remove Scene Numbers" fountain-remove-scene-numbers]
     "---"
     ["Display Scene Numbers in Margin"
      (customize-set-variable 'fountain-scene-numbers-display-in-margin
                              (not fountain-scene-numbers-display-in-margin))
      :style toggle
      :selected fountain-scene-numbers-display-in-margin])
    "---"
    ["Insert Metadata..." auto-insert]
    ["Insert Synopsis" fountain-insert-synopsis]
    ["Insert Note" fountain-insert-note]
    ["Count Pages" fountain-count-pages]
    ["Insert Page Break..." fountain-insert-page-break]
    ["Refresh Continued Dialog" fountain-contd-dialog-refresh]
    ["Update Auto-Completion" fountain-completion-update]
    "---"
    ("Syntax Highlighting"
     ["Minimum"
      (fountain-set-font-lock-decoration 1)
      :style radio
      :selected (= (fountain-get-font-lock-decoration) 1)]
     ["Default"
      (fountain-set-font-lock-decoration 2)
      :style radio
      :selected (= (fountain-get-font-lock-decoration) 2)]
     ["Maximum"
      (fountain-set-font-lock-decoration 3)
      :style radio
      :selected (= (fountain-get-font-lock-decoration) 3)]
     "---"
     ["Hide Emphasis Delimiters"
      (customize-set-variable 'fountain-hide-emphasis-delim
                              (not fountain-hide-emphasis-delim))
      :style toggle
      :selected fountain-hide-emphasis-delim]
     ["Hide Syntax Characters"
      (customize-set-variable 'fountain-hide-syntax-chars
                              (not fountain-hide-syntax-chars))
      :style toggle
      :selected fountain-hide-syntax-chars])
    "---"
    ["Display Elements Auto-Aligned"
     (customize-set-variable 'fountain-align-elements
                             (not fountain-align-elements))
     :style toggle
     :selected fountain-align-elements]
    ["Auto-Upcase Scene Headings"
     (customize-set-variable 'fountain-auto-upcase-scene-headings
                             (not fountain-auto-upcase-scene-headings))
     :style toggle
     :selected fountain-auto-upcase-scene-headings]
    ["Add Continued Dialog"
     (customize-set-variable 'fountain-add-contd-dialog
                             (not fountain-add-contd-dialog))
     :style toggle
     :selected fountain-add-contd-dialog]
    "---"
    ["Run Export Command" fountain-export-shell-command]
    "---"
    ["Save Options" fountain-save-options]
    ["Customize Mode" (customize-group 'fountain)]
    ["Customize Faces" (customize-group 'fountain-faces)]))

(defun fountain-save-options ()
  "Save `fountain-mode' options with `customize'."
  (interactive)
  (let (unsaved)
    (dolist (option '(fountain-align-elements
                      fountain-auto-upcase-scene-headings
                      fountain-add-contd-dialog
                      fountain-scene-numbers-display-in-margin
                      fountain-hide-emphasis-delim
                      fountain-hide-syntax-chars
                      fountain-shift-all-elements
                      font-lock-maximum-decoration
                      fountain-page-size))
      (when (customize-mark-to-save option) (setq unsaved t)))
    (when unsaved (custom-save-all))))


;;; Mode Definition

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.fountain\\'" . fountain-mode))

;;;###autoload
(define-derived-mode fountain-mode text-mode "Fountain"
  "Major mode for screenwriting in Fountain markup."
  :group 'fountain
  (fountain-init-vars)
  (face-remap-add-relative 'default 'fountain)
  (add-hook 'post-self-insert-hook #'fountain-auto-upcase nil t)
  (when fountain-patch-emacs-bugs (fountain-patch-emacs-bugs))
  (jit-lock-register #'fountain-redisplay-scene-numbers))

(provide 'fountain-mode)

;; Local Variables:
;; coding: utf-8
;; fill-column: 72
;; indent-tabs-mode: nil
;; require-final-newline: t
;; End:

;;; fountain-mode.el ends here
