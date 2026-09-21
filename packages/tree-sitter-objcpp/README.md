# tree-sitter-objcpp

An Objective-C++ grammar for tree-sitter, used by Helix to highlight `.m` and
`.mm` files.

## Why this exists

Helix ships no Objective-C support at all. There is no `objc` entry in its
language list and no grammar behind one, so `.m` and `.mm` files open as plain
text. The single attempt to add it upstream,
[helix-editor/helix#6119](https://github.com/helix-editor/helix/pull/6119), was
closed as stale in April 2024 on the grounds that its queries had been copied
from another project rather than adapted, and nobody picked it up again.

## How it is built

Objective-C++ is C++ plus a bolt-on object model. Restating C++ would mean
reimplementing templates, overloads, fold expressions and concepts, so this
grammar inherits `tree-sitter-cpp` and writes only the Objective-C half:

- `@interface` / `@implementation` / `@protocol`, categories, class extensions
- instance variable blocks and visibility specifiers
- `@property` with attributes, `@synthesize`, `@dynamic`
- method declarations and definitions, including keyword selectors and variadics
- message expressions, `super`, nested sends
- block literals and block pointer declarators
- boxed literals: `@"s"`, `@42`, `@YES`, `@[]`, `@{}`, `@()`
- `@selector`, `@protocol()`, `@encode`, `@available`
- `@try` / `@catch` / `@finally` / `@throw`, `@autoreleasepool`, `@synchronized`
- fast enumeration (`for (id x in xs)`)
- ARC and nullability qualifiers, Interface Builder markers, `typeof`

Because it inherits C++, the same grammar handles plain Objective-C (`.m`).
The C++ rules simply never match there.

## Parse rate

Measured with `tree-sitter parse --stat`, counting files that parse with no
error node at all. Three corpora: every Objective-C header in the macOS SDK;
the `.m`/`.mm` sources of AFNetworking, SDWebImage and React Native; and the
wxWidgets Cocoa backend, which mixes heavy C++ with Cocoa and leans hard on
its own macros.

| grammar | SDK headers (6154) | app code (509) | wxWidgets (327) |
| --- | --- | --- | --- |
| `tree-sitter-cpp` (what this inherits) | 18.2% | — | 7.3% |
| `tree-sitter-grammars/tree-sitter-objc` | 19.5% | — | — |
| **this grammar** | **66.6%** | **90.0%** | **79.2%** |

The SDK headers are a deliberately brutal corpus. They are written for the
preprocessor, not for a parser, and much of what remains is unparseable in
principle — chiefly declarations split across `#if` and `#else` branches, where
neither branch is a complete construct on its own.

Every gain came from measuring rather than guessing, but *what* was measured
mattered as much as that it was. Counting the first error in each failing file
worked until error nodes began spanning whole regions, at which point the
reported position was where recovery gave up rather than where the problem
was; several apparent failures turned out to parse perfectly in isolation. The
later rounds instead take the first *innermost* error node per file, which
sits on the token that actually failed. Two of the largest wins below were
invisible until then.

1. **Unexpanded macros.** `NS_ASSUME_NONNULL_BEGIN` alone on a line was being
   absorbed as a type name, swallowing the declaration after it and
   desynchronising the rest of the file. Recognising SCREAMING_SNAKE_CASE as a
   macro roughly doubled the rate, 18.4% to 35.5%.
2. **`[[` is not always a C++ attribute.** C++ lexes `[[` as one token, so every
   `[[NSRunLoop mainRunLoop] runMode:...]` in a file was read as the start of an
   attribute. Splitting it into two tokens and letting the parser choose took
   application code from 55.6% to 71.1%.
3. **Class declarations inside `#if`.** A top-level `#if` wraps *block* items,
   not top-level ones, so an `@implementation` behind a `#if TARGET_OS_MAC` —
   which is most of them — did not parse. 71.1% to 80.4%.
4. **Apple's enum macros**, `typedef NS_ENUM(NSInteger, Foo) { ... };`,
   including availability macros on individual members and a trailing one after
   the closing brace.
5. **A macro standing in for `override`.** Libraries older than C++11 wrap the
   keyword so they can compile either way; wxWidgets spells it `wxOVERRIDE` and
   uses it on nearly every method it declares. 47.4% to 70.6% on wxWidgets.
6. **Macro arguments as opaque text**, via the external scanner. 43.0% to
   46.6% on headers.
7. **`__has_include(<header.h>)`**, a macro among property attributes, and
   `class __exported Foo`. 46.6% to 51.5%.
8. **Trailing macros on declarations**, both after a function's parameter list
   and before the semicolon of a variable declaration. 51.5% to 54.9%.
9. **Macros inside include guards.** The single largest remaining win, and the
   one the sharper instrument found: macros were admitted at file scope but not
   as block items, and every Apple header opens with `#ifndef`. So none of the
   macro handling above actually worked in a real header. 54.9% to 65.3%.
10. **A stray semicolon after a macro** that supplies its own, as in
    `RCT_EXPORT_MODULE();`, and **concatenated strings where only the first
    piece carries its sigil**. Together 83.3% to 87.2% on application code.
11. **An `else` split from its branch by a preprocessor boundary**, by letting
    the clause stand without a body. 74.3% to 78.0% on wxWidgets.

## Known limits

Splitting the `[[` token, which is what makes nested message sends work, costs
two C++ constructs that also open with a single bracket. Both fail to parse:

- **C++17 structured bindings**, `auto [a, b] = pair;`
- **Lambda init-captures**, `[&a = x_](auto fn) { ... }`

The trade was settled by counting across the test corpora: nested message sends
appear in 586 files, structured bindings in 2 and init-captures in 3. See the
`attribute_declaration` comment in `grammar.js` for what was tried.

- **A macro call in ordinary statement position is a call expression**, not a
  macro invocation, so one whose arguments are not expressions will not parse
  inside a function body. The alternative was worse: admitting macros there
  silently turned every `EXPECT_TRUE(x);` and `RCT_ASSERT(y);` in every
  function into a macro invocation, with no error to show for it.
- **A macro standing in for a whole type** (`typedef CALLBACK_API_C(OSStatus,
  Fn)(int);`) does not parse. Adding it cost 13 points on the SDK headers and
  23 on wxWidgets, because it makes every macro call ambiguous with a type.
  These appear only in Carbon-era headers for APIs deprecated since 10.8.
- **`id` and `Class` are ordinary identifiers**, not keywords, because real
  code uses both as variable names. They are highlighted by name rather than
  by node type, so an unusual declaration such as `NSObject *id;` will colour
  its variable as a type.

- **Protocol qualifiers have no node of their own.** `id<NSCopying>` and
  `NSObject<NSCopying>` are both read as template types, the same shape C++
  gives a template instantiation. Telling a protocol list apart from
  Objective-C lightweight generics means knowing whether the name is a generic
  class, which is a symbol table's job. Both hold type identifiers and
  highlight identically.
- **`.h` is left to C and C++.** Objective-C headers end in `.h`, but so does
  every C project's, and claiming the extension would mis-highlight far more
  files than it fixed.
- **A macro between the type and the name** (`CV_EXPORT const CFStringRef
  CV_NONNULL kCVBufferKey;`) is not handled. Admitting one there makes every
  macro call ambiguous between a standalone item and a modifier on what
  follows; it was tried twice and measured worse on all three corpora both
  times.
- **Declarations split across `#if` and `#else`**, where a `typedef` opens in
  one branch and its body follows outside, cannot be parsed without running the
  preprocessor. A tree-sitter tree is strictly nested, so a construct that
  straddles a conditional boundary has no representation. This is most of what
  still fails in the SDK headers, along with headers that deliberately hide an
  unbalanced brace inside `#if 0`.
- **A bodyless `else` is accepted**, which C does not allow. That is the
  deliberate trade for the split-branch case above; see `else_clause`.
- **Macro names are matched by shape**, as an optional short lowercase vendor
  prefix followed by underscore-separated uppercase: `NS_ASSUME_NONNULL_BEGIN`,
  `wxBEGIN_EVENT_TABLE`, `CG_EXTERN`. A macro named like an ordinary identifier
  is invisible to that rule, except in the `override` position where any
  identifier is accepted.
- **Macro arguments are opaque text**, not parsed code. In general they are not
  expressions — `NS_SWIFT_NAME(active(status:))` carries selector syntax,
  `RCT_NOT_IMPLEMENTED(-(id)init)` carries a method declaration, and
  `API_AVAILABLE(macos(10.15.4))` carries a version number that is not a C
  literal — so the grammar declines to guess and keeps the text whole. Nothing
  inside a macro call is highlighted, which is at least uniform.
- **A root class with protocols and no superclass** (`@interface Foo <NSObject>`)
  reads its protocol list as a generic parameter list. Both nodes hold type
  identifiers, so nothing downstream notices.

## Working on it

```sh
npm install
npm run generate      # regenerate src/parser.c from grammar.js
npm test              # run test/corpus
npm run parse -- FILE # parse a file and print the tree
```

The queries cover highlights, indents, injections, locals and textobjects.
`locals.scm` inherits C's rather than C++'s, since C++ ships none of its own.

`src/` is committed, so Nix can build the parser without Node. Regenerate and
commit it whenever `grammar.js` changes.

`src/scanner.c` carries two things. The raw string literal scanner is vendored
from `tree-sitter-cpp` with its exported symbols renamed, because the inherited
C++ grammar declares external tokens for it; re-copy it if those ever change.
The macro argument scanner is ours, and counts balanced parentheses so that a
macro call can be skipped over whatever its arguments look like.

## Licence

MIT. `src/scanner.c` is derived from tree-sitter-cpp, also MIT.
