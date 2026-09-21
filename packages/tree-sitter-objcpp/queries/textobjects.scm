; Objective-C++ textobjects, for helix's `mif` / `maf` / `mic` / `mac` and
; friends.

; inherits: cpp

(objc_method_definition
  body: (_) @function.inside) @function.around

(objc_method_declaration) @function.around

(block_expression
  body: (_) @function.inside) @function.around

[
  (objc_class_interface)
  (objc_class_implementation)
  (objc_protocol_declaration)
] @class.around

; No `@class.inside` for the three above. Their members are repeated directly
; on the class rather than wrapped in a body node, so a capture can only name
; one member at a time, not the span of all of them — `mic` would select the
; method under the cursor rather than the class body, which is worse than
; falling back. Giving the grammar an explicit body node would fix it, at the
; cost of a tree shape change that every test and query would have to follow.
;
; The ivar block *is* a real node, so it behaves properly.
(objc_instance_variables) @class.around

(objc_method_parameter
  name: (identifier) @parameter.inside) @parameter.around

(objc_message_argument
  value: (_) @parameter.inside) @parameter.around

(objc_dictionary_entry) @entry.around
