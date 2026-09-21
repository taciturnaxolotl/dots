; Objective-C++ indentation.
;
; The inherited C and C++ queries already handle every construct they know
; about, including the outdent on `}`, `]` and `)`. Only the Objective-C
; additions belong here; repeating the closing brackets would outdent them
; twice.

; inherits: cpp

; Class bodies, ivar blocks and the bracketed literals all indent their
; contents.
[
  (objc_class_interface)
  (objc_class_implementation)
  (objc_protocol_declaration)
  (objc_instance_variables)
  (objc_message_selector)
  (objc_array_literal)
  (objc_dictionary_literal)
  (objc_property_attribute_list)
] @indent

; `@end` closes a class body the way `}` closes a block.
"@end" @outdent

; `@required` / `@optional` divide a protocol body, and `@public` / `@private`
; an ivar block, the way an access specifier divides a C++ class. They line up
; with the declaration rather than with its members.
[
  (objc_availability_specifier)
  (objc_visibility_specifier)
] @outdent
