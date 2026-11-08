%{
#include "ast.h"
#include "parser_module.h"
#include "parser.tab.h"
#include <stdlib.h>
#include <string.h>
%}

%option noyywrap
%option reentrant
%option bison-bridge
%option yylineno

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
"true"|"false"      { yylval->str = strdup(yytext); return LITERAL_BOOL; }

{ID}                { yylval->str = strdup(yytext); return IDENTIFIER; }

0[xX]{HEXDIGIT}+    { yylval->str = strdup(yytext); return LITERAL_HEX; }
0[bB][01]+          { yylval->str = strdup(yytext); return LITERAL_BITS; }
{DIGIT}+            { yylval->str = strdup(yytext); return LITERAL_DEC; }

\"([^\\\"]|\\.)*\"  { yylval->str = strdup(yytext); return LITERAL_STR; }
\'([^\\']|\\.)\'    { yylval->str = strdup(yytext); return LITERAL_CHAR; }

"=="                { yylval->str = strdup(yytext); return OP_EQ; }
"!="                { yylval->str = strdup(yytext); return OP_NEQ; }
"<="                { yylval->str = strdup(yytext); return OP_LE; }
">="                { yylval->str = strdup(yytext); return OP_GE; }
"&&"                { yylval->str = strdup(yytext); return OP_AND; }
"||"                { yylval->str = strdup(yytext); return OP_OR; }
"+"                 { yylval->str = strdup(yytext); return OP_PLUS; }
"-"                 { yylval->str = strdup(yytext); return OP_MINUS; }
"*"                 { yylval->str = strdup(yytext); return OP_MUL; }
"/"                 { yylval->str = strdup(yytext); return OP_DIV; }
"%"                 { yylval->str = strdup(yytext); return OP_MOD; }
"="                 { yylval->str = strdup(yytext); return OP_ASSIGN; }
"<"                 { yylval->str = strdup(yytext); return OP_LT; }
">"                 { yylval->str = strdup(yytext); return OP_GT; }
"!"                 { yylval->str = strdup(yytext); return OP_NOT; }
"<<"                { yylval->str = strdup(yytext); return OP_SHL; }
">>"                { yylval->str = strdup(yytext); return OP_SHR; }
"&"                 { yylval->str = strdup(yytext); return OP_BIT_AND; }
"|"                 { yylval->str = strdup(yytext); return OP_BIT_OR; }
"^"                 { yylval->str = strdup(yytext); return OP_BIT_XOR; }
"~"                 { yylval->str = strdup(yytext); return OP_BIT_NOT; }

"("                 { return LPAREN; }
")"                 { return RPAREN; }
"{"                 { return LBRACE; }
"}"                 { return RBRACE; }
"["                 { return LBRACKET; }
"]"                 { return RBRACKET; }
";"                 { return SEMICOLON; }
","                 { return COMMA; }

.                   { /* Carácter no reconocido */ }

%%