/**
 * @file External scanner for Objective-C++.
 *
 * Two jobs.
 *
 * The first is inherited: the C++ grammar declares external tokens for raw
 * string literals (`R"delim(...)delim"`), whose delimiters cannot be matched
 * by a regular expression. That half is vendored verbatim from
 * tree-sitter-cpp (MIT, Max Brunsfeld et al.) with the exported symbols
 * renamed from `tree_sitter_cpp_*` to `tree_sitter_objcpp_*`. It is copied
 * rather than included so that `src/` stays self-contained and builds without
 * node_modules present. Re-copy it if the C++ grammar's externals change.
 *
 * The second is ours: the body of a macro call whose arguments are not C
 * expressions. Objective-C headers are full of these, and the parser cannot
 * expand macros to find out what they mean:
 *
 *     NS_SWIFT_NAME(active(status:))
 *     RCT_NOT_IMPLEMENTED(-(instancetype)initWithCoder:(NSCoder *)c)
 *
 * `status:` is selector syntax, so parsing it as an argument list fails and
 * takes the whole enclosing declaration with it. Matching balanced
 * parentheses needs a counter, which a regular expression does not have,
 * hence the scanner.
 */

#include "tree_sitter/alloc.h"
#include "tree_sitter/parser.h"

#include <assert.h>
#include <string.h>
#include <wctype.h>

enum TokenType { RAW_STRING_DELIMITER, RAW_STRING_CONTENT, MACRO_ARGUMENT_TEXT };

/// The spec limits delimiters to 16 chars
#define MAX_DELIMITER_LENGTH 16

typedef struct {
    uint8_t delimiter_length;
    wchar_t delimiter[MAX_DELIMITER_LENGTH];
} Scanner;

static inline void advance(TSLexer *lexer) { lexer->advance(lexer, false); }

static inline void reset(Scanner *scanner) {
    scanner->delimiter_length = 0;
    memset(scanner->delimiter, 0, sizeof scanner->delimiter);
}

/// Scan the raw string delimiter in R"delimiter(content)delimiter"
static bool scan_raw_string_delimiter(Scanner *scanner, TSLexer *lexer) {
    if (scanner->delimiter_length > 0) {
        // Closing delimiter: must exactly match the opening delimiter.
        // We already checked this when scanning content, but this is how we
        // know when to stop. We can't stop at ", because R"""hello""" is valid.
        for (int i = 0; i < scanner->delimiter_length; ++i) {
            if (lexer->lookahead != scanner->delimiter[i]) {
                return false;
            }
            advance(lexer);
        }
        reset(scanner);
        return true;
    }

    // Opening delimiter: record the d-char-sequence up to (.
    // d-char is any basic character except parens, backslashes, and spaces.
    for (;;) {
        if (scanner->delimiter_length >= MAX_DELIMITER_LENGTH || lexer->eof(lexer) || lexer->lookahead == '\\' ||
            iswspace(lexer->lookahead)) {
            return false;
        }
        if (lexer->lookahead == '(') {
            // Rather than create a token for an empty delimiter, we fail and
            // let the grammar fall back to a delimiter-less rule.
            return scanner->delimiter_length > 0;
        }
        scanner->delimiter[scanner->delimiter_length++] = lexer->lookahead;
        advance(lexer);
    }
}

/// Scan the raw string content in R"delimiter(content)delimiter"
static bool scan_raw_string_content(Scanner *scanner, TSLexer *lexer) {
    // The progress made through the delimiter since the last ')'.
    // The delimiter may not contain ')' so a single counter suffices.
    for (int delimiter_index = -1;;) {
        // If we hit EOF, consider the content to terminate there.
        // This forms an incomplete raw_string_literal, and models the code
        // well.
        if (lexer->eof(lexer)) {
            lexer->mark_end(lexer);
            return true;
        }

        if (delimiter_index >= 0) {
            if (delimiter_index == scanner->delimiter_length) {
                if (lexer->lookahead == '"') {
                    return true;
                }
                delimiter_index = -1;
            } else {
                if (lexer->lookahead == scanner->delimiter[delimiter_index]) {
                    delimiter_index += 1;
                } else {
                    delimiter_index = -1;
                }
            }
        }

        if (delimiter_index == -1 && lexer->lookahead == ')') {
            // The content doesn't include the )delimiter" part.
            // We must still scan through it, but exclude it from the token.
            lexer->mark_end(lexer);
            delimiter_index = 0;
        }

        advance(lexer);
    }
}

/// Scan the body of a macro call, up to but not including the `)` that closes
/// it. The grammar supplies the surrounding parentheses.
///
/// Quotes and comments are tracked so that a parenthesis inside a string or a
/// comment does not throw off the depth count. Running off the end of the file
/// means the call was never closed, so the token is refused and the parser
/// reports the error where it really is.
static inline bool is_digit_ish(int32_t c) {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

static bool scan_macro_argument_text(TSLexer *lexer) {
    unsigned depth = 0;
    bool consumed_any = false;
    // Whether the character just consumed could end a numeric literal, which
    // is what tells a C++ digit separator from an opening quote.
    bool after_digit = false;

    for (;;) {
        if (lexer->eof(lexer)) {
            return false;
        }

        switch (lexer->lookahead) {
            case ')':
                if (depth == 0) {
                    // Leave the closing paren for the grammar. An empty
                    // argument list is spelled `()`, and a zero-width token
                    // would be rejected, so refuse it there and let the
                    // grammar's `optional` cover that case.
                    lexer->mark_end(lexer);
                    return consumed_any;
                }
                depth--;
                break;

            case '(':
                depth++;
                break;

            case '\'':
                // `1'000'000` — a quote directly after a digit is a C++ digit
                // separator, not the start of a character literal. Scanning it
                // as a literal would swallow everything up to the next quote,
                // closing parenthesis included.
                if (after_digit) {
                    break;
                }
                // fall through
            case '"': {
                const int32_t quote = lexer->lookahead;
                advance(lexer);
                while (!lexer->eof(lexer) && lexer->lookahead != quote) {
                    if (lexer->lookahead == '\\') {
                        advance(lexer);
                        if (lexer->eof(lexer)) {
                            return false;
                        }
                    }
                    advance(lexer);
                }
                if (lexer->eof(lexer)) {
                    return false;
                }
                break;
            }

            case '/':
                advance(lexer);
                consumed_any = true;
                if (lexer->lookahead == '/') {
                    while (!lexer->eof(lexer) && lexer->lookahead != '\n') {
                        advance(lexer);
                    }
                } else if (lexer->lookahead == '*') {
                    advance(lexer);
                    int32_t previous = 0;
                    while (!lexer->eof(lexer) && !(previous == '*' && lexer->lookahead == '/')) {
                        previous = lexer->lookahead;
                        advance(lexer);
                    }
                    if (lexer->eof(lexer)) {
                        return false;
                    }
                    // Consume the closing slash here. Leaving it would send the
                    // next iteration back into this same case, where a comment
                    // followed directly by `/` reads as a line comment and eats
                    // the rest of the line.
                    advance(lexer);
                }
                after_digit = false;
                continue;

            default:
                break;
        }

        after_digit = is_digit_ish(lexer->lookahead);
        advance(lexer);
        consumed_any = true;
    }
}

void *tree_sitter_objcpp_external_scanner_create() {
    Scanner *scanner = (Scanner *)ts_calloc(1, sizeof(Scanner));
    memset(scanner, 0, sizeof(Scanner));
    return scanner;
}

bool tree_sitter_objcpp_external_scanner_scan(void *payload, TSLexer *lexer, const bool *valid_symbols) {
    Scanner *scanner = (Scanner *)payload;

    if (valid_symbols[RAW_STRING_DELIMITER] && valid_symbols[RAW_STRING_CONTENT]) {
        // we're in error recovery
        return false;
    }

    // No skipping leading whitespace: raw-string grammar is space-sensitive.
    if (valid_symbols[RAW_STRING_DELIMITER]) {
        lexer->result_symbol = RAW_STRING_DELIMITER;
        return scan_raw_string_delimiter(scanner, lexer);
    }

    if (valid_symbols[RAW_STRING_CONTENT]) {
        lexer->result_symbol = RAW_STRING_CONTENT;
        return scan_raw_string_content(scanner, lexer);
    }

    if (valid_symbols[MACRO_ARGUMENT_TEXT]) {
        lexer->result_symbol = MACRO_ARGUMENT_TEXT;
        return scan_macro_argument_text(lexer);
    }

    return false;
}

unsigned tree_sitter_objcpp_external_scanner_serialize(void *payload, char *buffer) {
    static_assert(MAX_DELIMITER_LENGTH * sizeof(wchar_t) < TREE_SITTER_SERIALIZATION_BUFFER_SIZE,
                  "Serialized delimiter is too long!");

    Scanner *scanner = (Scanner *)payload;
    size_t size = scanner->delimiter_length * sizeof(wchar_t);
    memcpy(buffer, scanner->delimiter, size);
    return (unsigned)size;
}

void tree_sitter_objcpp_external_scanner_deserialize(void *payload, const char *buffer, unsigned length) {
    assert(length % sizeof(wchar_t) == 0 && "Can't decode serialized delimiter!");

    Scanner *scanner = (Scanner *)payload;
    scanner->delimiter_length = length / sizeof(wchar_t);
    if (length > 0) {
        memcpy(&scanner->delimiter[0], buffer, length);
    }
}

void tree_sitter_objcpp_external_scanner_destroy(void *payload) {
    Scanner *scanner = (Scanner *)payload;
    ts_free(scanner);
}
