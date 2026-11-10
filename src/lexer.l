%{
#include "ast.h"
#include "parser_module.h"
#include "parser.tab.h"
#include <stdlib.h>
#include <string.h>


/*
 * Duplica el texto de un token.
 * Devuelve NULL si falla la reserva de memoria.
 */
static char* lexer_dup_text(const char* text) {
#ifdef AST_TEST_FAULT_INJECTION
    if (getenv("AST_TEST_FAIL_LEX_DUP") != NULL) {
        return NULL;
    }
#endif

    return strdup(text);
}

/*
 * Copia el token y comunica los fallos al parser.
 *
 * En caso de error, devuelve 0 (EOF).
 * parse_text() rechazará el resultado porque
 * ctx->has_error queda activado.
 */
#define RETURN_DUP_TOKEN(TOKEN) do {                  \
    yylval->str = lexer_dup_text(yytext);             \
                                                      \
    if (yylval->str == NULL) {                        \
        ParseContext* ctx = yyextra;                  \
                                                      \
        if (ctx != NULL) {                           \
            ctx->has_error = 1;                      \
            error_list_add(                           \
                ctx->errors,                          \
                yylineno,                            \
                "Error de memoria en el lexer"       \
            );                                        \
        }                                             \
                                                      \
        return 0;                                     \
    }                                                 \
                                                      \
    return (TOKEN);                                   \
} while (0)


%}

%option noyywrap
%option reentrant
%option bison-bridge
%option yylineno
%option extra-type="ParseContext *"
%option nounput noinput

DIGIT    [0-9]
HEXDIGIT [0-9A-Fa-f]
ID       [a-zA-Z_][a-zA-Z0-9_]*

%%

[ \t\r\n]+          { /* Ignorar espacios en blanco */ }
"//".*              { /* Ignorar comentario de línea */ }
"/*"([^*]|\*+[^*/])*\*+"/" { /* Ignorar comentario de bloque */ }

"if"                { return IF; }
"else"              { return ELSE; }
"while"             { return WHILE; }
"do"                { return DO; }
"break"             { return BREAK; }
"bool"              { return KW_BOOL; }
"byte"              { return KW_BYTE; }
"int"               { return KW_INT; }
"uint"              { return KW_UINT; }
"long"              { return KW_LONG; }
"ulong"             { return KW_ULONG; }
"char"              { return KW_CHAR; }
"string"            { return KW_STRING; }

"true"|"false"       { RETURN_DUP_TOKEN(LITERAL_BOOL); }

{ID}                 { RETURN_DUP_TOKEN(IDENTIFIER); }

0[xX]{HEXDIGIT}+     { RETURN_DUP_TOKEN(LITERAL_HEX); }
0[bB][01]+           { RETURN_DUP_TOKEN(LITERAL_BITS); }
{DIGIT}+             { RETURN_DUP_TOKEN(LITERAL_DEC); }

\"([^\\\"]|\\.)*\"  { RETURN_DUP_TOKEN(LITERAL_STR); }
\'([^\\']|\\.)\'    { RETURN_DUP_TOKEN(LITERAL_CHAR); }

"==" { RETURN_DUP_TOKEN(OP_EQ); }
"!=" { RETURN_DUP_TOKEN(OP_NEQ); }
"<=" { RETURN_DUP_TOKEN(OP_LE); }
">=" { RETURN_DUP_TOKEN(OP_GE); }

"&&" { RETURN_DUP_TOKEN(OP_AND); }
"||" { RETURN_DUP_TOKEN(OP_OR); }

"+" { RETURN_DUP_TOKEN(OP_PLUS); }
"-" { RETURN_DUP_TOKEN(OP_MINUS); }
"*" { RETURN_DUP_TOKEN(OP_MUL); }
"/" { RETURN_DUP_TOKEN(OP_DIV); }
"%" { RETURN_DUP_TOKEN(OP_MOD); }

"=" { RETURN_DUP_TOKEN(OP_ASSIGN); }

"<" { RETURN_DUP_TOKEN(OP_LT); }
">" { RETURN_DUP_TOKEN(OP_GT); }
"!" { RETURN_DUP_TOKEN(OP_NOT); }

"<<" { RETURN_DUP_TOKEN(OP_SHL); }
">>" { RETURN_DUP_TOKEN(OP_SHR); }

"&" { RETURN_DUP_TOKEN(OP_BIT_AND); }
"|" { RETURN_DUP_TOKEN(OP_BIT_OR); }
"^" { RETURN_DUP_TOKEN(OP_BIT_XOR); }
"~" { RETURN_DUP_TOKEN(OP_BIT_NOT); }

"("                 { return LPAREN; }
")"                 { return RPAREN; }
"{"                 { return LBRACE; }
"}"                 { return RBRACE; }
"["                 { return LBRACKET; }
"]"                 { return RBRACKET; }
";"                 { return SEMICOLON; }
","                 { return COMMA; }

.                   { return INVALID;}

%%