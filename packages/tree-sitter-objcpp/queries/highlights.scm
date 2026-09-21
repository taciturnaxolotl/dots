; Objective-C++ highlights.
;
; Inherits the whole C++ query set and adds only the Objective-C half. The
; inherited patterns are spliced in where the directive appears, so everything
; below takes priority over them.

; inherits: cpp

; ----------------------------------------------------------------------------
; Keywords
; ----------------------------------------------------------------------------

[
  "@interface"
  "@implementation"
  "@protocol"
  "@end"
  "@class"
  "@compatibility_alias"
  "@property"
  "@synthesize"
  "@dynamic"
  "@selector"
  "@encode"
  "@available"
  "__builtin_available"
] @keyword

"@import" @keyword.control.import

[
  "@required"
  "@optional"
  "@private"
  "@protected"
  "@public"
  "@package"
] @keyword.directive

[
  "@try"
  "@catch"
  "@finally"
  "@throw"
] @keyword.control.exception

[
  "@autoreleasepool"
  "@synchronized"
] @keyword.control

; `in` is only a keyword inside fast enumeration; elsewhere it is an ordinary
; identifier, so this is anchored to the loop rather than matched as a word.
(objc_for_in_statement
  "in" @keyword.control.repeat)

; ----------------------------------------------------------------------------
; Types
; ----------------------------------------------------------------------------

(objc_builtin_type) @type.builtin

; Typedefs from <objc/objc.h> that read as built-ins to anyone writing the
; language, even though the compiler treats them as ordinary names.
((type_identifier) @type.builtin
  (#any-of? @type.builtin
    "id" "Class" "SEL" "IMP" "BOOL" "Protocol" "NSInteger" "NSUInteger" "CGFloat"))

(objc_class_interface
  name: (type_identifier) @type)
(objc_class_interface
  superclass: (type_identifier) @type)
(objc_class_implementation
  name: (type_identifier) @type)
(objc_class_implementation
  superclass: (type_identifier) @type)

(objc_protocol_declaration
  name: (type_identifier) @type)
(objc_protocol_reference_list
  protocol: (type_identifier) @type)
(objc_protocol_expression
  name: (type_identifier) @type)

(objc_category
  name: (identifier) @type)

(objc_type_parameter
  name: (type_identifier) @type.parameter)

(objc_enum_specifier
  name: (type_identifier) @type)

(objc_class_forward_declaration
  name: (type_identifier) @type)
(objc_protocol_forward_declaration
  name: (type_identifier) @type)
(objc_compatibility_alias
  alias: (type_identifier) @type
  name: (type_identifier) @type)

(objc_module_import
  module: (identifier) @namespace)

; ----------------------------------------------------------------------------
; Methods and messages
; ----------------------------------------------------------------------------

(objc_method_scope) @keyword.storage.modifier

(objc_method_selector
  name: (identifier) @function.method)
(objc_method_parameter
  keyword: (identifier) @function.method)
(objc_method_parameter
  name: (identifier) @variable.parameter)

(objc_message_selector
  name: (identifier) @function.method)
(objc_message_argument
  keyword: (identifier) @function.method)

; `@selector(tableView:didSelectRowAtIndexPath:)` names a method, so colour it
; like one rather than as a bare string of identifiers.
(objc_selector_name
  (identifier) @function.method)

(objc_macro_invocation
  name: (objc_macro_name) @function.macro)
(objc_enum_specifier
  macro: (objc_enum_macro_name) @function.macro)

; A macro's arguments are unexpanded text rather than parsed code, so they are
; dimmed as a unit instead of being coloured as though their meaning were known.
(objc_macro_argument_text) @comment.unused

; ----------------------------------------------------------------------------
; Properties
; ----------------------------------------------------------------------------

(objc_property_attribute) @keyword.storage.modifier
(objc_property_attribute
  value: (identifier) @function.method)

(objc_property_synthesize
  property: (identifier) @variable.other.member)
(objc_property_synthesize
  ivar: (identifier) @variable.other.member)
(objc_property_dynamic
  property: (identifier) @variable.other.member)

(objc_visibility_specifier) @keyword.directive
(objc_availability_specifier) @keyword.directive

(objc_platform_version
  platform: (identifier) @constant.builtin)

; ----------------------------------------------------------------------------
; Qualifiers
; ----------------------------------------------------------------------------

(objc_method_type_qualifier) @keyword.storage.modifier

((type_qualifier) @keyword.storage.modifier
  (#match? @keyword.storage.modifier "^(__|_N)"))

; ----------------------------------------------------------------------------
; Values
; ----------------------------------------------------------------------------

(objc_super) @variable.builtin

; `self` is a real implicit parameter rather than a keyword, so it stays an
; identifier in the tree and is picked out here.
((identifier) @variable.builtin
  (#eq? @variable.builtin "self"))

((identifier) @constant.builtin
  (#any-of? @constant.builtin "nil" "Nil" "NULL"))

((identifier) @constant.builtin.boolean
  (#any-of? @constant.builtin.boolean "YES" "NO"))

(objc_string_literal) @string

; The `@` of a boxed literal belongs to the literal, not to the expression
; around it.
(objc_boxed_expression "@" @punctuation.special)
(objc_array_literal "@" @punctuation.special)
(objc_dictionary_literal "@" @punctuation.special)

; ----------------------------------------------------------------------------
; Blocks
; ----------------------------------------------------------------------------

(block_expression "^" @punctuation.special)
(block_pointer_declarator "^" @punctuation.special)
(abstract_block_pointer_declarator "^" @punctuation.special)
