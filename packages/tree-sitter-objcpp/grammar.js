/**
 * @file Objective-C++ grammar for tree-sitter
 * @author Kieran Klukas
 * @license MIT
 *
 * Objective-C++ is C++ plus a bolt-on object model. Rather than restate the
 * ~3500 lines of C++ (templates, overloads, fold expressions, concepts) this
 * grammar inherits `tree-sitter-cpp` and adds only the Objective-C half:
 * interfaces, protocols, properties, message sends, blocks, boxed literals
 * and the `@`-prefixed statements.
 *
 * The same file covers plain Objective-C (`.m`). C++ constructs simply never
 * appear there, and the inherited rules cost nothing when unused.
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

const CPP = require('tree-sitter-cpp/grammar');
const C = require('tree-sitter-c/grammar');

// tree-sitter-cpp does not re-export its precedence table, so the few levels
// we need to sit next to are restated here. For reference, C uses
// CALL 15, FIELD 16, SUBSCRIPT 17, and C++ adds LAMBDA 18.
const PREC = {
  // Message sends bind like calls: `[a b].c` and `[a b][0]` must postfix.
  MESSAGE: 15,
  // A block literal is a primary expression; keep it above binary `^` (xor).
  BLOCK: 16,
  // `@interface Foo (Bar)` — the parens are a category, outranking the
  // parenthesised declarator C++ would otherwise find there.
  CATEGORY: 20,
  // `@implementation Foo { ... }` — the brace opens an ivar block, not the
  // free-floating compound statement that C permits at top level.
  IVARS: 20,
};

/**
 * Attributes legal inside `@property (...)`.
 * `direct` and `class` are clang extensions; `null_resettable` is nullability.
 */
const PROPERTY_ATTRIBUTES = [
  'assign', 'atomic', 'class', 'copy', 'direct', 'nonatomic', 'nonnull',
  'null_resettable', 'nullable', 'readonly', 'readwrite', 'retain', 'strong',
  'unsafe_unretained', 'weak',
];

/**
 * ARC ownership and nullability qualifiers. These are legal anywhere `const`
 * is, so they join the inherited `type_qualifier`.
 */
const OBJC_TYPE_QUALIFIERS = [
  // Interface Builder markers. `IBOutlet` and friends expand to nothing and
  // sit where a qualifier would; they are mixed case, so the general macro
  // rule cannot see them.
  'IBOutlet', 'IBOutletCollection', 'IBInspectable', 'IBDesignable',
  '__autoreleasing', '__block', '__bridge', '__bridge_retained',
  '__bridge_transfer', '__kindof', '__nonnull', '__null_unspecified',
  '__nullable', '__strong', '__unsafe_unretained', '__unused', '__used',
  '__weak', '_Nonnull', '_Null_unspecified', '_Nullable',
];

/**
 * Parameter direction and bare nullability keywords. Unlike the list above
 * these are only legal inside the parentheses of a method type, and must stay
 * out of the general qualifier set: a global `in` would make the separator in
 * `for (id x in xs)` indistinguishable from a qualifier.
 */
const OBJC_METHOD_TYPE_QUALIFIERS = [
  'bycopy', 'byref', 'in', 'inout', 'nonnull', 'null_unspecified',
  'nullable', 'oneway', 'out',
];

/**
 * The Objective-C declaration forms, shared between `_top_level_item` and
 * `_block_item`. A top-level `#if` wraps block items, so anything reachable
 * at file scope has to be reachable in both or it breaks inside a guard.
 *
 * @param {GrammarSymbols<string>} $
 */
const OBJC_DECLARATIONS = $ => [
  $.objc_class_interface,
  $.objc_class_implementation,
  $.objc_protocol_declaration,
  $.objc_class_forward_declaration,
  $.objc_protocol_forward_declaration,
  $.objc_compatibility_alias,
  $.objc_module_import,
];

/**
 * The Objective-C statement forms, legal wherever a statement is.
 *
 * @param {GrammarSymbols<string>} $
 */
const OBJC_STATEMENTS = $ => [
  $.objc_autoreleasepool_statement,
  $.objc_synchronized_statement,
  $.objc_try_statement,
  $.objc_throw_statement,
  $.objc_for_in_statement,
];

module.exports = grammar(CPP, {
  name: 'objcpp',

  externals: ($, original) => original.concat([
    $.objc_macro_argument_text,
  ]),

  conflicts: ($, original) => original.concat([
    // `[a b]` (message) vs `[a]{}` (lambda) vs `a[b]` (subscript). All three
    // open with `[`, so a captured name and a receiver expression have to be
    // carried side by side until what follows the bracket settles it.
    [$._lambda_capture_identifier, $.expression],

    // A receiver may be a bare type (`[NSString class]`) or a bare variable
    // (`[str length]`); both reduce from `identifier`.
    [$._objc_receiver, $.expression],

    // `void (^)(int)` (abstract, a type) vs `void (^cb)(int)` (named). The
    // caret is shared; the name that decides only arrives afterwards. C has
    // the identical standoff between its pointer declarators.
    [$.block_pointer_declarator, $.abstract_block_pointer_declarator],

    // `@interface Foo <X>` — generic parameter list or protocol list? Both
    // are legal grammar here, so keep both stacks alive.
    [$.objc_type_parameter, $.objc_protocol_reference_list],

    // With `[[` split into two tokens, a doubled bracket can open a C++
    // attribute, a lambda nested in a lambda capture, or a message send whose
    // receiver is itself a message. All readings must survive until the
    // contents decide.
    [$.attribute, $._lambda_capture_identifier],
    [$.attribute, $.expression],

    // A leading `__attribute__` on a class is also a declaration modifier for
    // whatever might otherwise follow; only `@interface` settles it.
    [$._declaration_modifiers, $.objc_class_interface],


  ]),

  rules: {
    // Preprocessor conditionals whose branches hold class-body items rather
    // than top-level ones. Apple's headers gate properties and methods behind
    // `#if TARGET_OS_IPHONE` constantly, and without these the `#if` ends the
    // useful parse of the interface. C parameterises the same helper for
    // struct fields and enumerators; these are the Objective-C equivalents.
    ...C.preprocIf('_in_objc_interface', $ => $._objc_interface_item),
    ...C.preprocIf('_in_objc_implementation', $ => $._objc_implementation_item),

    // And one whose branches hold top-level items, so that a macro guarded by
    // an include guard still parses. C's own `preproc_if` is defined over
    // *block* items, which are equally the contents of every compound
    // statement; putting macros in there would turn `EXPECT_TRUE(x);` inside
    // a function into a macro invocation rather than a call. `_top_level_item`
    // filters C's variants out in favour of these.
    ...C.preprocIf('_in_objc_top_level', $ => $._top_level_item),


    // ---------------------------------------------------------------
    // Entry points
    // ---------------------------------------------------------------

    /**
     * Carries the Objective-C declarations and the macro forms, and swaps C's
     * preprocessor conditionals for variants whose branches hold top-level
     * items rather than block items.
     *
     * That swap is what lets a macro inside an include guard parse without
     * also admitting one inside every function body.
     */
    _top_level_item: ($, original) => choice(
      ...original.members.filter(m =>
        m.name !== 'preproc_if' && m.name !== 'preproc_ifdef'),
      alias($.preproc_if_in_objc_top_level, $.preproc_if),
      alias($.preproc_ifdef_in_objc_top_level, $.preproc_ifdef),
      ...OBJC_DECLARATIONS($),
      $.objc_macro_invocation,
      $.objc_enum_definition,
    ),

    /**
     * The branch body is optional, which C does not allow.
     *
     * Preprocessor-heavy C++ splits an `if` from its alternative across a
     * conditional boundary all the time:
     *
     *     #if defined(__MAC_10_13)
     *         if (available) { useModern(); }
     *         else
     *     #endif
     *         { useLegacy(); }
     *
     * A tree-sitter tree is strictly nested, so an `else` inside the guard
     * cannot own a body outside it, and the construct is unparseable as
     * written. Letting the clause stand without a body makes both halves parse
     * as siblings instead, which highlights correctly even though the tree no
     * longer records that they belong together. `prec.right` keeps an ordinary
     * `else { ... }` attached to its body.
     *
     * The cost is that a bodyless `else` no longer registers as an error. For
     * a highlighter that is the right side to err on: valid code is never
     * mis-parsed, only invalid code is tolerated.
     */
    else_clause: $ => prec.right(seq('else', optional($.statement))),

    /**
     * Also carries the class declarations and the statements.
     *
     * Deliberately *not* the macro forms. A block item is the content of every
     * compound statement as well as of C's `preproc_if`, so a macro admitted
     * here would swallow every `EXPECT_TRUE(x);` and `RCT_ASSERT(y);` in a
     * function body, turning a call into a macro invocation with no error to
     * show for it. Guarded macros are handled by `preproc_if_in_objc_top_level`
     * instead.
     */
    _block_item: ($, original) => choice(
      original,
      ...OBJC_DECLARATIONS($),
      ...OBJC_STATEMENTS($),
    ),

    _non_case_statement: ($, original) => choice(
      original,
      ...OBJC_STATEMENTS($),
    ),

    _expression_not_binary: ($, original) => choice(
      original,
      $.message_expression,
      $.block_expression,
      $.objc_selector_expression,
      $.objc_protocol_expression,
      $.objc_encode_expression,
      $.objc_available_expression,
      $.objc_string_literal,
      $.objc_boxed_expression,
      $.objc_array_literal,
      $.objc_dictionary_literal,
      $.objc_super,
    ),

    // ---------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------

    type_specifier: ($, original) => choice(
      original,
      $.objc_builtin_type,
      $.objc_typeof_specifier,
      $.objc_enum_specifier,
    ),

    /**
     * Apple's enum macros, which are how essentially every enumeration in the
     * system frameworks is spelled:
     *
     *     typedef NS_ENUM(NSInteger, SKProductPeriodUnit) { ... };
     *     typedef NS_OPTIONS(NSUInteger, MTLResourceUsage) { ... };
     *
     * The macro expands to an enum with an explicit backing type, so it is
     * modelled as a type specifier rather than left to the generic macro
     * fallback, which cannot reach a type position.
     *
     * Matched by the `_ENUM` / `_OPTIONS` suffix rather than a fixed list, so
     * `CF_ENUM`, `NS_CLOSED_ENUM`, `NS_ERROR_ENUM` and every vendor's variant
     * work without enumerating them. The narrow suffix keeps the token from
     * shadowing ordinary all-caps type names.
     */
    objc_enum_specifier: $ => prec.right(seq(
      field('macro', $.objc_enum_macro_name),
      '(',
      field('backing_type', $.type_descriptor),
      optional(seq(',', field('name', $._type_identifier))),
      ')',
      optional(field('body', $.enumerator_list)),
    )),

    objc_enum_macro_name: _ => token(prec(2, /[A-Z][A-Z0-9_]*_(ENUM|OPTIONS)/)),

    /**
     * Allows an availability macro between an enum member and its value:
     *
     *     MTLTextureTypeCubeArray API_AVAILABLE(macos(10.11)) = 6,
     *
     * Apple annotates enum members this way constantly. Because the macro sits
     * inside the enum body, one of them takes the entire surrounding
     * `typedef NS_ENUM(...) { ... }` down with it, which is why this single
     * position accounts for so many failed headers.
     */
    enumerator: $ => seq(
      field('name', $.identifier),
      repeat($.objc_macro_invocation),
      optional(seq('=', field('value', $.expression))),
    ),

    /**
     * `typedef NS_ENUM(NSInteger, Unit) { ... };`
     *
     * The macro supplies the typedef name itself, so unlike an ordinary
     * `typedef` there is no trailing declarator. C's `type_definition`
     * insists on one, hence this variant. The form that *does* name a
     * declarator still goes through `type_definition` as usual.
     *
     * A trailing availability macro after the closing brace is common enough
     * to admit here too: `} API_AVAILABLE(macos(13.0), ios(16.0));`
     */
    objc_enum_definition: $ => seq(
      'typedef',
      field('type', $.objc_enum_specifier),
      repeat($.attribute_specifier),
      repeat($.objc_macro_invocation),
      ';',
    ),

    /**
     * `__typeof__(self)`, the backbone of the weak/strong dance:
     *
     *     __weak typeof(self) weakSelf = self;
     *
     * C reaches this through `macro_type_specifier`, but C++ replaces
     * `type_specifier` wholesale and drops it, leaving `typeof` unusable in a
     * type position. Restored here as a sibling of C++'s own `decltype`.
     *
     * The operand is preferably an expression, so that `typeof(self)` marks
     * `self` as a variable; a genuine type (`typeof(NSString *)`) still works
     * through the second branch.
     */
    objc_typeof_specifier: $ => seq(
      choice('typeof', '__typeof', '__typeof__'),
      '(',
      field('value', choice(prec.dynamic(1, $.expression), $.type_descriptor)),
      ')',
    ),

    /**
     * `instancetype` only ever appears as a method return type, so it is safe
     * to treat as a keyword.
     *
     * `id` and `Class` are *not* here, though clang treats them as keywords.
     * They are declared as plain typedefs in <objc/objc.h>, and real code uses
     * both as ordinary variable names — wxWidgets writes `int id = ...;
     * if (id == wxID_HELP)` throughout its Cocoa backend. Making them keywords
     * broke every such file. They are ordinary identifiers here and are picked
     * out by the highlight queries by name, the same way `self`, `nil` and
     * `YES` are.
     */
    objc_builtin_type: _ => 'instancetype',

    /**
     * Protocol qualifiers have no rule of their own.
     *
     * `id<NSCopying>` and `NSObject<NSCopying>` are both `template_type`, the
     * same shape C++ gives a template instantiation. Telling a protocol list
     * apart from Objective-C lightweight generics needs to know whether the
     * name is a generic class, which is a symbol table's job rather than a
     * parser's. Both hold type identifiers and highlight identically, so
     * nothing downstream notices.
     */

    type_qualifier: (_, original) => choice(
      original,
      ...OBJC_TYPE_QUALIFIERS,
    ),

    /**
     * Admits an unexpanded macro where `override` or `final` would go, and
     * where an availability annotation trails a function declaration:
     *
     *     virtual void SetLabel(const wxString&) wxOVERRIDE;
     *     CG_EXTERN CFTypeID CGFunctionGetTypeID(void) API_AVAILABLE(macos(10.2));
     *
     * Frameworks older than C++11 wrap `override` so they can compile either
     * way, and Apple annotates nearly every function this way. Neither macro
     * is reliably SCREAMING_SNAKE, but the position right after a parameter
     * list admits nothing else, so a bare identifier is safe to accept.
     *
     * Hooked here rather than on `virtual_specifier` itself, which is also
     * reachable after a class name and would make `class Foo {` ambiguous.
     */
    _function_postfix: ($, original) => choice(
      original,
      prec.right(repeat1(seq(
        alias($.identifier, $.objc_macro_name),
        optional($.objc_macro_arguments),
      ))),
    ),

    /**
     * Allows a trailing macro before the semicolon:
     *
     *     CG_EXTERN const CFStringRef kCGWindowNumber
     *         API_AVAILABLE(macos(10.15.4), ios(13.4));
     *
     * This declarator names a variable rather than a function, so
     * `_function_postfix` never sees it. Note the three-part version number,
     * which is not a C literal at all — another reason macro arguments are
     * kept as opaque text.
     */
    declaration: $ => seq(
      $._declaration_specifiers,
      commaSep1(field('declarator', choice(
        seq(
          $._declarator,
          optional($.gnu_asm_expression),
        ),
        $.init_declarator,
      ))),
      repeat($.objc_macro_invocation),
      ';',
    ),

    /**
     * Lets `#if __has_include(<OpenGL/OpenGL.h>)` parse.
     *
     * C models a preprocessor call's arguments as preprocessor expressions,
     * and a bracketed header path is not one. `__has_include` is the only
     * common operator that takes one, but it guards the OpenGL and GLES
     * headers across the SDK.
     */
    _preproc_expression: ($, original) => choice(
      original,
      $.system_lib_string,
      $.string_literal,
    ),

    /**
     * `class __exported IOFoo : public IOBar`
     *
     * A clang visibility attribute that sits between `class` and the name. It
     * is spelled in lowercase, so the macro rule cannot see it, and IOKit's
     * C++ headers put it on nearly every class they declare.
     */
    _class_declaration: ($, original) => seq(
      optional('__exported'),
      original,
    ),

    /**
     * Kept as the inherited set.
     *
     * Admitting `objc_macro_invocation` here would catch a macro sitting
     * between the type and the name, as in
     * `CV_EXPORT const CFStringRef CV_NONNULL kCVBufferKey;`. It has been
     * tried twice and measured worse both times: it makes every macro call
     * ambiguous between "standalone item" and "modifier on what follows",
     * needs four extra conflicts to build at all, and then costs 0.5 points
     * on Apple's headers, 3.5 on application code and 10 on wxWidgets. A
     * leading macro already parses as a standalone item immediately before
     * the declaration, which is nearly as good and free.
     */
    _declaration_modifiers: ($, original) => original,

    /**
     * An unexpanded preprocessor macro standing where a declaration would.
     *
     * Apple's headers are full of these — `NS_ASSUME_NONNULL_BEGIN` alone on a
     * line, `CG_EXTERN` before a function, `API_AVAILABLE(macos(10.9))` after
     * a method. A parser cannot expand them, and without this rule the first
     * one in a file is absorbed as a type name, swallowing the declaration
     * that follows and desynchronising everything after it. That costs the
     * rest of the file its highlighting, which is the whole point of the
     * exercise.
     *
     * The name is matched by shape rather than from a fixed list: uppercase
     * with at least one underscore. That covers every vendor prefix
     * (`NS_`, `CG_`, `API_`, `MTL_`, `SK_`) without enumerating them, while
     * leaving genuine all-caps types like `BOOL`, `SEL` and `IMP`, and
     * constants like `YES` and `NULL`, as ordinary identifiers.
     *
     * Deliberately unavailable inside expressions and statement bodies, so
     * that a macro constant such as `INT_MAX` in real code is never mistaken
     * for one of these.
     */
    objc_macro_invocation: $ => prec.dynamic(-1, prec.right(seq(
      field('name', $.objc_macro_name),
      optional(field('arguments', $.objc_macro_arguments)),
    ))),

    /**
     * The arguments of an unexpanded macro, held as opaque text.
     *
     * They are not parsed as expressions because in general they are not
     * expressions. `NS_SWIFT_NAME(active(status:))` carries selector syntax,
     * and `RCT_NOT_IMPLEMENTED(-(instancetype)initWithCoder:(NSCoder *)c)`
     * carries a whole method declaration. Only the preprocessor can say what
     * the text means, so the grammar declines to guess and keeps it whole.
     *
     * Treating every macro call the same way also keeps the result
     * predictable: no macro's arguments are highlighted, rather than some
     * being highlighted and others not depending on whether they happened to
     * look like C.
     *
     * The text itself comes from the external scanner, which counts balanced
     * parentheses and so can find the closing one. An empty `MACRO()` yields
     * no text at all, hence the `optional`.
     */
    objc_macro_arguments: $ => seq(
      '(',
      optional($.objc_macro_argument_text),
      ')',
    ),

    /**
     * Outranks `identifier` lexically, otherwise the tie is broken in favour
     * of a plain identifier and this rule never fires. Only reachable in the
     * positions listed above, so expressions are unaffected.
     *
     * The optional lowercase head allows a vendor prefix: wxWidgets writes
     * `wxBEGIN_EVENT_TABLE` and `wxCLANG_WARNING_RESTORE` where Apple writes
     * `NS_ASSUME_NONNULL_BEGIN`. The underscore-separated uppercase body is
     * what actually marks it as a macro.
     */
    objc_macro_name: _ => token(prec(1, /[a-z]{0,3}[A-Z][A-Z0-9]*(_[A-Z0-9]+)+/)),

    /**
     * A trailing annotation macro spelled in lowercase, as clang's own are:
     * `- (void)reload __deprecated_msg("use x");`
     *
     * Arguments are required. Without them the name would be indistinguishable
     * from the next keyword of the selector itself, since both are bare
     * identifiers in the same position.
     */
    objc_lowercase_macro: $ => prec.dynamic(-1, seq(
      field('name', alias($.identifier, $.objc_macro_name)),
      field('arguments', $.objc_macro_arguments),
    )),

    // ---------------------------------------------------------------
    // Block pointer declarators — `void (^name)(int)`
    // ---------------------------------------------------------------

    _declarator: ($, original) => choice(original, $.block_pointer_declarator),
    _field_declarator: ($, original) => choice(
      original,
      alias($.block_pointer_field_declarator, $.block_pointer_declarator),
    ),
    _type_declarator: ($, original) => choice(
      original,
      alias($.block_pointer_type_declarator, $.block_pointer_declarator),
    ),
    _abstract_declarator: ($, original) => choice(
      original,
      $.abstract_block_pointer_declarator,
    ),

    // `prec.dynamic` mirrors C's treatment of `pointer_declarator`: when a
    // named and an abstract reading both survive to the end, prefer the named.
    block_pointer_declarator: $ => prec.dynamic(1, prec.right(seq(
      '^',
      repeat($.type_qualifier),
      repeat($.objc_macro_invocation),
      field('declarator', optional($._declarator)),
    ))),

    block_pointer_field_declarator: $ => prec.right(seq(
      '^',
      repeat($.type_qualifier),
      repeat($.objc_macro_invocation),
      field('declarator', optional($._field_declarator)),
    )),

    block_pointer_type_declarator: $ => prec.right(seq(
      '^',
      repeat($.type_qualifier),
      repeat($.objc_macro_invocation),
      field('declarator', optional($._type_declarator)),
    )),

    /**
     * The abstract form carries macros too. An annotated block type with no
     * parameter name is how Apple writes most completion handlers:
     * `- (void)load:(void (^ NS_SWIFT_SENDABLE)(NSError *))handler;`
     */
    abstract_block_pointer_declarator: $ => prec.right(seq(
      '^',
      repeat($.type_qualifier),
      repeat($.objc_macro_invocation),
      field('declarator', optional($._abstract_declarator)),
    )),

    // ---------------------------------------------------------------
    // @interface / @implementation / @protocol
    // ---------------------------------------------------------------

    objc_class_interface: $ => seq(
      // `__attribute__((objc_subclassing_restricted))` and friends may precede
      // the class, as Apple's own generated headers write them.
      repeat($.attribute_specifier),
      '@interface',
      field('name', $._type_identifier),
      optional(field('type_parameters', $.objc_type_parameter_list)),
      optional(field('category', $.objc_category)),
      optional(seq(':', field('superclass', $._type_identifier))),
      optional(field('protocols', $.objc_protocol_reference_list)),
      // A trailing availability macro (`@interface Foo : Bar API_AVAILABLE(...)`)
      // needs no clause of its own: `objc_macro_invocation` is already a body
      // item, so it is simply picked up as the first one.
      optional(field('ivars', $.objc_instance_variables)),
      repeat(field('body', $._objc_interface_item)),
      '@end',
    ),

    objc_class_implementation: $ => seq(
      '@implementation',
      field('name', $._type_identifier),
      optional(field('category', $.objc_category)),
      optional(seq(':', field('superclass', $._type_identifier))),
      optional(field('ivars', $.objc_instance_variables)),
      repeat(field('body', $._objc_implementation_item)),
      '@end',
    ),

    objc_protocol_declaration: $ => seq(
      '@protocol',
      field('name', $._type_identifier),
      optional(field('protocols', $.objc_protocol_reference_list)),
      repeat(field('body', $._objc_interface_item)),
      '@end',
    ),

    /**
     * `@interface Foo (Private)` and the empty class extension `@interface Foo ()`.
     *
     * Directly after a class name a parenthesised identifier is always a
     * category, never the parenthesised declarator or call expression that the
     * inherited C++ rules would otherwise see, hence the precedence.
     */
    objc_category: $ => prec(PREC.CATEGORY, seq(
      '(', optional(field('name', $.identifier)), ')',
    )),

    /**
     * Lightweight generics on the declaration side: `@interface Box<T> ...`.
     *
     * Immediately after a class name this outranks a protocol reference list,
     * which is the right call for modern code. The cost is that a root class
     * carrying only protocols and no superclass (`@interface Foo <NSObject>`,
     * essentially extinct) reads its protocols as type parameters. Both node
     * kinds hold type identifiers, so nothing downstream notices.
     */
    objc_type_parameter_list: $ => prec.dynamic(1, seq(
      '<',
      commaSep1(field('parameter', $.objc_type_parameter)),
      '>',
    )),

    objc_type_parameter: $ => seq(
      optional(choice('__covariant', '__contravariant')),
      field('name', $._type_identifier),
      optional(seq(':', field('bound', $.type_descriptor))),
    ),

    objc_protocol_reference_list: $ => seq(
      '<',
      commaSep1(field('protocol', $._type_identifier)),
      '>',
    ),

    objc_instance_variables: $ => prec(PREC.IVARS, seq(
      '{',
      repeat(choice(
        $.objc_visibility_specifier,
        $._field_declaration_list_item,
      )),
      '}',
    )),

    objc_visibility_specifier: _ => choice(
      '@private', '@protected', '@public', '@package',
    ),

    _objc_interface_item: $ => choice(
      $.objc_method_declaration,
      $.objc_property_declaration,
      $.objc_availability_specifier,
      $.objc_macro_invocation,
      $.declaration,
      $.type_definition,
      $._empty_declaration,
      alias($.preproc_if_in_objc_interface, $.preproc_if),
      alias($.preproc_ifdef_in_objc_interface, $.preproc_ifdef),
      $.preproc_include,
      $.preproc_def,
      $.preproc_function_def,
      $.preproc_call,
    ),

    /**
     * Deliberately not `$._top_level_item`. C admits a bare compound statement
     * at top level, which would make the `{` after `@implementation Foo`
     * ambiguous with the ivar block. Listing the items that can really appear
     * in a class body removes the ambiguity at the source instead of papering
     * over it with a conflict.
     */
    _objc_implementation_item: $ => choice(
      $.objc_method_definition,
      $.objc_property_synthesize,
      $.objc_property_dynamic,
      $.objc_property_declaration,
      $.objc_class_forward_declaration,
      $.objc_protocol_forward_declaration,
      $.objc_macro_invocation,
      $.function_definition,
      $.declaration,
      $.type_definition,
      $._empty_declaration,
      // A stray semicolon, as left behind by a macro that already supplies its
      // own: `RCT_EXPORT_MODULE();`. C++ allows one in a class body for the
      // same reason. Admitted only here, not in an interface body, where it
      // would be indistinguishable from `@protocol Foo;`.
      ';',
      alias($.preproc_if_in_objc_implementation, $.preproc_if),
      alias($.preproc_ifdef_in_objc_implementation, $.preproc_ifdef),
      $.preproc_include,
      $.preproc_def,
      $.preproc_function_def,
      $.preproc_call,
    ),

    objc_availability_specifier: _ => choice('@required', '@optional'),

    // ---------------------------------------------------------------
    // Methods
    // ---------------------------------------------------------------

    /** `- (void)doThing:(NSString *)a with:(int)b;` */
    objc_method_declaration: $ => seq(
      field('scope', $.objc_method_scope),
      optional(field('return_type', $.objc_method_type)),
      field('selector', $.objc_method_selector),
      repeat($.attribute_specifier),
      repeat(choice($.objc_macro_invocation, $.objc_lowercase_macro)),
      ';',
    ),

    objc_method_definition: $ => seq(
      field('scope', $.objc_method_scope),
      optional(field('return_type', $.objc_method_type)),
      field('selector', $.objc_method_selector),
      repeat($.attribute_specifier),
      // An availability macro may sit between the selector and the body, just
      // as it may before the semicolon of a declaration.
      repeat($.objc_macro_invocation),
      optional(';'),
      field('body', $.compound_statement),
    ),

    /** `-` is an instance method, `+` a class method. */
    objc_method_scope: _ => choice('-', '+'),

    /**
     * The parenthesised return or parameter type.
     *
     * Direction keywords sit in their own rule rather than in `type_qualifier`
     * so that they stay scoped to this position; `type_descriptor` already
     * accepts the ARC and nullability qualifiers on its own.
     */
    objc_method_type: $ => seq(
      '(',
      repeat($.objc_method_type_qualifier),
      $.type_descriptor,
      ')',
    ),

    objc_method_type_qualifier: _ => choice(...OBJC_METHOD_TYPE_QUALIFIERS),

    /**
     * Either a bare selector (`init`) or one or more keyword/argument pairs
     * (`initWithFrame:` `style:`). Trailing `, ...` marks a variadic method.
     */
    /**
     * Right-associative so that the parameter list keeps absorbing keywords.
     * A trailing lowercase annotation macro starts with a bare identifier in
     * the same position as the next selector keyword, and only the token after
     * it tells them apart.
     */
    objc_method_selector: $ => prec.right(choice(
      field('name', $._objc_selector_identifier),
      seq(
        repeat1(field('parameter', $.objc_method_parameter)),
        optional(seq(',', '...')),
      ),
    )),

    objc_method_parameter: $ => seq(
      optional(field('keyword', $._objc_selector_identifier)),
      ':',
      optional(field('type', $.objc_method_type)),
      repeat($.attribute_specifier),
      field('name', $.identifier),
    ),

    /**
     * Selector pieces are not restricted to C identifiers: `- (void)in:`,
     * `- (id)copy`, `- (void)default:` are all legal. Admit the C and
     * Objective-C keywords that show up in real frameworks.
     */
    _objc_selector_identifier: $ => choice(
      $.identifier,
      alias(choice(
        'in', 'out', 'inout', 'copy', 'class', 'default', 'new', 'delete',
        'instancetype', 'static', 'return', 'for', 'while', 'do',
        'switch', 'case', 'break', 'continue', 'if', 'else', 'signed',
        'unsigned', 'const', 'volatile', 'auto', 'register', 'extern',
        'struct', 'union', 'enum', 'typedef', 'sizeof', 'this', 'template',
        'operator', 'namespace', 'using', 'try', 'catch', 'throw', 'public',
        'private', 'protected', 'virtual', 'inline', 'explicit', 'friend',
      ), $.identifier),
    ),

    // ---------------------------------------------------------------
    // Properties
    // ---------------------------------------------------------------

    /** `@property (nonatomic, copy, nullable) NSString *name;` */
    objc_property_declaration: $ => seq(
      '@property',
      optional(field('attributes', $.objc_property_attribute_list)),
      $._declaration_specifiers,
      commaSep1(field('declarator', $._declarator)),
      repeat($.attribute_specifier),
      repeat($.objc_macro_invocation),
      ';',
    ),

    objc_property_attribute_list: $ => seq(
      '(',
      commaSep(field('attribute', $.objc_property_attribute)),
      ')',
    ),

    /**
     * Plain attributes, the two that take a value (`getter=isDone`,
     * `setter=setDone:`), and an unexpanded macro. Apple ships the last of
     * these in its own headers: `@property(readonly, NS_NONATOMIC_IOSONLY)`.
     */
    objc_property_attribute: $ => choice(
      ...PROPERTY_ATTRIBUTES,
      $.objc_macro_invocation,
      seq(
        field('name', choice('getter', 'setter')),
        '=',
        field('value', $._objc_selector_identifier),
        optional(':'),
      ),
    ),

    /** `@synthesize name = _name, other;` */
    objc_property_synthesize: $ => seq(
      '@synthesize',
      commaSep1(seq(
        field('property', $.identifier),
        optional(seq('=', field('ivar', $.identifier))),
      )),
      ';',
    ),

    objc_property_dynamic: $ => seq(
      '@dynamic',
      commaSep1(field('property', $.identifier)),
      ';',
    ),

    // ---------------------------------------------------------------
    // Forward declarations and module imports
    // ---------------------------------------------------------------

    objc_class_forward_declaration: $ => seq(
      '@class',
      commaSep1(seq(
        field('name', $._type_identifier),
        optional(field('type_parameters', $.objc_type_parameter_list)),
      )),
      ';',
    ),

    objc_protocol_forward_declaration: $ => seq(
      '@protocol',
      commaSep1(field('name', $._type_identifier)),
      ';',
    ),

    objc_compatibility_alias: $ => seq(
      '@compatibility_alias',
      field('alias', $._type_identifier),
      field('name', $._type_identifier),
      ';',
    ),

    /** `@import Foundation;` and `@import Foundation.NSString;` */
    objc_module_import: $ => seq(
      '@import',
      field('module', sep1($.identifier, '.')),
      ';',
    ),

    // ---------------------------------------------------------------
    // Message expressions
    // ---------------------------------------------------------------

    /**
     * C++ attributes, respelled with two separate bracket tokens.
     *
     * C lexes `[[` as a single token, which is fatal here: a nested message
     * send also opens with two brackets, so every
     * `[[NSRunLoop mainRunLoop] runMode:...]` in the file would be lexed as
     * the start of an attribute and lost. Splitting the token lets the parser
     * decide between the two readings instead of the lexer.
     *
     * This is not free. Two C++ constructs that open with a single bracket
     * become collateral damage, because a lone `[` can now begin an attribute
     * and the parser commits to that reading before the next token could rule
     * it out:
     *
     *   - C++17 structured bindings, `auto [a, b] = pair;`
     *   - lambda init-captures, `[&a = x_, &b = y()](auto fn) { ... }`
     *
     * Raising the declarator's precedence, lowering the attribute's, and
     * declaring the conflict at four different levels were each tried and none
     * moved it. The two conflicts above are load-bearing: the grammar will not
     * build without them, and they are what pulls capture lists into the
     * expression reading.
     *
     * The trade was settled by counting rather than by taste. Across the test
     * corpora, nested message sends appear in 586 files; structured bindings
     * in 2 and init-captures in 3. Objective-C++ that never sends a nested
     * message is not Objective-C++.
     *
     * `[ [nodiscard] ]` with spaces is also accepted now, which C++ does not
     * allow. That one is harmless.
     */
    attribute_declaration: $ => seq(
      '[', '[', commaSep1($.attribute), ']', ']',
    ),

    /**
     * `[receiver selector:arg otherKeyword:arg]`
     *
     * Shares its opening bracket with subscripts, lambda captures and C++
     * attributes; the declared conflicts above let the parser explore them.
     * The dynamic precedence settles the leftovers in favour of a message
     * send, which in Objective-C source is overwhelmingly the right guess.
     */
    message_expression: $ => prec.dynamic(1, prec(PREC.MESSAGE, seq(
      '[',
      field('receiver', $._objc_receiver),
      field('selector', $.objc_message_selector),
      ']',
    ))),

    _objc_receiver: $ => choice(
      $.expression,
      $.objc_super,
      $.objc_builtin_type,
    ),

    objc_message_selector: $ => choice(
      field('name', $._objc_selector_identifier),
      seq(
        repeat1(field('argument', $.objc_message_argument)),
        // Variadic tail: `[NSString stringWithFormat:@"%@ %@", a, b]`
        repeat(seq(',', field('variadic_argument', $.expression))),
      ),
    ),

    objc_message_argument: $ => seq(
      optional(field('keyword', $._objc_selector_identifier)),
      ':',
      field('value', $.expression),
    ),

    /**
     * `super` is a receiver-only keyword. `self`, by contrast, is a real
     * implicit parameter and is assignable (`self = [super init]`), so it is
     * left as an ordinary identifier and picked out by the highlight queries.
     */
    objc_super: _ => 'super',

    // ---------------------------------------------------------------
    // Blocks
    // ---------------------------------------------------------------

    /**
     * `^{ ... }`, `^(NSError *e) { ... }`, `^BOOL(id a, id b) { ... }`
     *
     * Ranks above the inherited binary `^` so a statement-leading caret is
     * read as a block rather than as a dangling xor.
     */
    block_expression: $ => prec(PREC.BLOCK, seq(
      '^',
      optional(field('return_type', $.objc_block_return_type)),
      optional(field('parameters', $.parameter_list)),
      repeat($.attribute_specifier),
      field('body', $.compound_statement),
    )),

    /**
     * The return type of a block literal, spelled out rather than reusing
     * `type_descriptor`. A full descriptor would happily read the parameter
     * list as part of the type, turning `^BOOL(id a)` into a block returning
     * a function. Only a type and its pointers belong here.
     */
    objc_block_return_type: $ => seq(
      repeat($.type_qualifier),
      field('type', $.type_specifier),
      repeat($.type_qualifier),
      repeat(seq('*', repeat($.type_qualifier))),
    ),

    // ---------------------------------------------------------------
    // @-expressions
    // ---------------------------------------------------------------

    /** `@selector(tableView:didSelectRowAtIndexPath:)` */
    objc_selector_expression: $ => seq(
      '@selector',
      '(',
      field('selector', $.objc_selector_name),
      ')',
    ),

    objc_selector_name: $ => choice(
      $._objc_selector_identifier,
      repeat1(seq(optional($._objc_selector_identifier), ':')),
    ),

    objc_protocol_expression: $ => seq(
      '@protocol', '(', field('name', $._type_identifier), ')',
    ),

    objc_encode_expression: $ => seq(
      '@encode', '(', field('type', $.type_descriptor), ')',
    ),

    /** `@available(iOS 13.0, macOS 10.15, *)` */
    objc_available_expression: $ => seq(
      choice('@available', '__builtin_available'),
      '(',
      commaSep1(field('platform', choice($.objc_platform_version, '*'))),
      ')',
    ),

    objc_platform_version: $ => seq(
      field('platform', $.identifier),
      field('version', $.number_literal),
    ),

    // ---------------------------------------------------------------
    // Boxed literals
    // ---------------------------------------------------------------

    /** `@"text"`, and the adjacent-concatenation form `@"a" @"b"`. */
    /**
     * `@"text"`, and its concatenations.
     *
     * Adjacent pieces may repeat the `@` or leave it off, and real code mixes
     * both freely:
     *
     *     @"The loaders %@ and %@ both reported that"
     *      " they can load the URL %@, and have equal priority"
     *
     * Only the first piece needs the sigil, so everything after it is an
     * ordinary C string.
     */
    objc_string_literal: $ => prec.right(seq(
      '@',
      field('value', choice($.string_literal, $.raw_string_literal)),
      repeat(choice(
        seq('@', field('value', choice($.string_literal, $.raw_string_literal))),
        field('value', choice($.string_literal, $.raw_string_literal)),
      )),
    )),

    /** `@42`, `@YES`, `@'c'`, `@(expr)` */
    objc_boxed_expression: $ => seq(
      '@',
      field('value', choice(
        $.number_literal,
        $.char_literal,
        $.true,
        $.false,
        $.identifier,
        seq('(', $.expression, ')'),
      )),
    ),

    /** `@[a, b, c]` */
    objc_array_literal: $ => seq(
      '@', '[', commaSep(field('element', $.expression)), optional(','), ']',
    ),

    /** `@{key: value, ...}` */
    objc_dictionary_literal: $ => seq(
      '@', '{',
      commaSep(field('entry', $.objc_dictionary_entry)),
      optional(','),
      '}',
    ),

    objc_dictionary_entry: $ => seq(
      field('key', $.expression),
      ':',
      field('value', $.expression),
    ),

    // ---------------------------------------------------------------
    // Statements
    // ---------------------------------------------------------------

    objc_autoreleasepool_statement: $ => seq(
      '@autoreleasepool',
      field('body', $.compound_statement),
    ),

    objc_synchronized_statement: $ => seq(
      '@synchronized',
      '(', field('object', $.expression), ')',
      field('body', $.compound_statement),
    ),

    objc_try_statement: $ => seq(
      '@try',
      field('body', $.compound_statement),
      repeat(field('handler', $.objc_catch_clause)),
      optional(field('finalizer', $.objc_finally_clause)),
    ),

    objc_catch_clause: $ => seq(
      '@catch',
      '(', field('parameter', choice($.parameter_declaration, '...')), ')',
      field('body', $.compound_statement),
    ),

    objc_finally_clause: $ => seq(
      '@finally',
      field('body', $.compound_statement),
    ),

    objc_throw_statement: $ => seq(
      '@throw',
      optional(field('value', $.expression)),
      ';',
    ),

    /** Fast enumeration: `for (id item in collection) { ... }` */
    objc_for_in_statement: $ => prec(1, seq(
      'for',
      '(',
      field('initializer', choice(
        seq($._declaration_specifiers, field('declarator', $._declarator)),
        $.expression,
      )),
      'in',
      field('collection', $.expression),
      ')',
      field('body', $.statement),
    )),
  },
});

/**
 * Zero or more `rule`, comma separated.
 * @param {RuleOrLiteral} rule
 */
function commaSep(rule) {
  return optional(commaSep1(rule));
}

/**
 * One or more `rule`, comma separated.
 * @param {RuleOrLiteral} rule
 */
function commaSep1(rule) {
  return sep1(rule, ',');
}

/**
 * One or more `rule`, separated by `separator`.
 * @param {RuleOrLiteral} rule
 * @param {RuleOrLiteral} separator
 */
function sep1(rule, separator) {
  return seq(rule, repeat(seq(separator, rule)));
}
