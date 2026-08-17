/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

/**
 * Tree-sitter grammar for CedarLogic CDL v3 (S-expression format).
 *
 * CDL v3 structure:
 *   (cedarlogic
 *     (version 3)
 *     (generator "CedarLogic")
 *     (page INDEX
 *       (gate TYPE (uuid "...") (at X Y) (angle N) param*)
 *       (wire (ids "...") segment*)))
 *
 * Symbols are any non-delimiter chars (not whitespace, parens, or quotes).
 * Strings use \" and \\ escapes only.
 * No comments exist in the format.
 */
module.exports = grammar({
  name: "cdl",

  extras: ($) => [/\s/],

  rules: {
    // Root: a single top-level list
    source_file: ($) => $.list,

    // List: ( item* )
    list: ($) =>
      seq(
        "(",
        repeat(choice($.list, $.string, $.symbol)),
        ")"
      ),

    // String: "..." with \" and \\ escapes
    string: ($) =>
      seq(
        '"',
        repeat(
          choice(
            $.escape_sequence,
            /[^"\\]+/
          )
        ),
        '"'
      ),

    escape_sequence: (_) => /\\["\\]/,

    // Symbol: any run of non-delimiter characters
    // Delimiters are: whitespace, (, ), "
    symbol: (_) => /[^\s()"]+/,
  },
});
