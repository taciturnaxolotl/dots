; Objective-C++ locals, for scope-aware highlighting of parameters and
; locally-bound names.
;
; Inherits C's rather than C++'s: C++ ships no locals.scm of its own, so
; `inherits: cpp` here would pick up nothing.

; inherits: c

; A method body and a block body are both scopes, the same way a function
; definition is.
[
  (objc_method_definition)
  (block_expression)
] @local.scope

; The name in `- (void)moveTo:(CGPoint)point` is a parameter binding, not a
; reference to something defined elsewhere.
(objc_method_parameter
  name: (identifier) @local.definition.variable.parameter)

; A block's parameters come through the inherited `parameter_declaration`
; patterns, so they need nothing here.
