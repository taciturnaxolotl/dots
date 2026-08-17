;; CedarLogic CDL v3 highlights

;; Strings (default catch-all)
(string) @string
(escape_sequence) @constant.character.escape

;; Known CDL keywords (first element of a list)
(list
  .
  (symbol) @keyword
  (#match? @keyword "^(cedarlogic|version|generator|page|gate|wire|uuid|at|angle|gparam|lparam|ids|seg|pts|connect|cross)$"))

;; Gate type names: (gate "AA_AND2" ...)
(list
  (symbol) @_kw
  (#eq? @_kw "gate")
  (string) @type
  (#match? @type "^\""))

;; Segment orientation: (seg "id" h|v ...)
(list
  (symbol) @_kw
  (#eq? @_kw "seg")
  (string) @string.special
  (symbol) @variable.builtin
  (#match? @variable.builtin "^[hv]$"))

;; Parameter names: (gparam "NAME" "value") / (lparam "NAME" "value")
(list
  (symbol) @_kw
  (#match? @_kw "^(gparam|lparam)$")
  (string) @variable.parameter)

;; UUIDs: (uuid "...")
(list
  (symbol) @_kw
  (#eq? @_kw "uuid")
  (string) @string.special)

;; Wire IDs: (ids "a" "b" ...)
(list
  (symbol) @_kw
  (#eq? @_kw "ids")
  (string) @string.special)

;; Pin names in connect: (connect "gateUuid" "PIN")
(list
  (symbol) @_kw
  (#eq? @_kw "connect")
  (string) @string.special)

;; Cross references: (cross at "segId")
(list
  (symbol) @_kw
  (#eq? @_kw "cross")
  (string) @string.special)

;; Numbers: integers, decimals, and scientific notation (§5.2)
(symbol) @number
(#match? @number "^-?([0-9]+(\\.[0-9]*)?|\\.[0-9]+)([eE][+-]?[0-9]+)?$")

;; Special float values
(symbol) @constant.builtin
(#match? @constant.builtin "^(nan|inf|-inf)$")

;; Parentheses
["(" ")"] @punctuation.bracket
