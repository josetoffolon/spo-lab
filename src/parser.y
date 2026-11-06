%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "parser_module.h"
%}

%code requires {
    #include "ast.h"
    #include "parser_module.h"
}

%define api.pure full
%lex-param   { void* scanner }
%parse-param { void* scanner }
%parse-param { ParseContext* ctx }

%union {
    char* str;
    ASTNode* node;
}

/* Este bloque se inserta en parser.tab.h DESPUÉS de definir YYSTYPE */
%code provides {
    int yylex(YYSTYPE* yylval_param, void* yyscanner);
    void yyerror(void* scanner, ParseContext* ctx, const char* s);
}

%token <str> IDENTIFIER LITERAL_STR LITERAL_CHAR LITERAL_HEX LITERAL_BITS LITERAL_DEC LITERAL_BOOL
%token <str> OP_EQ OP_NEQ OP_LE OP_GE OP_AND OP_OR OP_PLUS OP_MINUS OP_MUL OP_DIV OP_MOD OP_ASSIGN OP_LT OP_GT OP_NOT
%token IF ELSE WHILE DO BREAK
%token KW_BOOL KW_BYTE KW_INT KW_UINT KW_LONG KW_ULONG KW_CHAR KW_STRING
%token LPAREN RPAREN LBRACE RBRACE LBRACKET RBRACKET SEMICOLON COMMA

%type <node> source sourceItem funcDef funcSignature argList argDef statement statementList block expr typeRef exprList optVarAssign varDeclTail

/* Precedencia de operadores (de menor a mayor) */
%right OP_ASSIGN
%left OP_OR
%left OP_AND
%left OP_EQ OP_NEQ
%left OP_LT OP_GT OP_LE OP_GE
%left OP_PLUS OP_MINUS
%left OP_MUL OP_DIV OP_MOD
%right OP_NOT
/* Los postfijos () y [] tienen la precedencia MÁS ALTA
   para que -f(x) se interprete como -(f(x)) y no (-f)(x) */
%left LPAREN LBRACKET

/* Resolver el "dangling else" */
%nonassoc IFX
%nonassoc ELSE

%start source

%%

source:
    /* vacío */ {
        $$ = create_node(NODE_PROGRAM, NULL);
        ctx->root = $$;
    }
    | source sourceItem {
        if ($1 != NULL && $2 != NULL) {
            add_child($1, $2);
            $$ = $1;
        } else {
            $$ = $1;
        }
        ctx->root = $$;
    }
    ;

sourceItem:
    funcDef { $$ = $1; }
    ;

funcDef:
    funcSignature block {
        $$ = $1;
        add_child($$, $2);
    }
    | funcSignature SEMICOLON { $$ = $1; }
    ;

funcSignature:
    IDENTIFIER LPAREN argList RPAREN {
        $$ = create_node(NODE_FUNC_DEF, $1);
        free($1);
        if ($3 != NULL) add_child($$, $3);
    }
    | typeRef IDENTIFIER LPAREN argList RPAREN {
        $$ = create_node(NODE_FUNC_DEF, $2);
        if ($1 != NULL) add_child($$, $1);
        free($2);
        if ($4 != NULL) add_child($$, $4);
    }
    ;

argList:
    /* vacío */ {
        $$ = create_node(NODE_ARG_LIST, NULL);
    }
    | argDef {
        $$ = create_node(NODE_ARG_LIST, NULL);
        add_child($$, $1);
    }
    | argList COMMA argDef {
        $$ = $1;
        add_child($$, $3);
    }
    ;

argDef:
    IDENTIFIER {
        $$ = create_node(NODE_IDENTIFIER, $1);
        free($1);
    }
    | typeRef IDENTIFIER {
        $$ = create_node(NODE_IDENTIFIER, $2);
        if ($1 != NULL) add_child($$, $1);
        free($2);
    }
    ;

    optVarAssign:
    /* vacío */ { $$ = NULL; }
    | OP_ASSIGN expr { $$ = $2; }
    ;

varDeclTail:
    /* vacío */ {
        $$ = create_node(NODE_DECL_LIST, NULL);
    }
    | varDeclTail COMMA IDENTIFIER optVarAssign {
        ASTNode* decl = create_node(NODE_IDENTIFIER, $3);

        if ($4 != NULL) {
            add_child(decl, $4);
        }

        add_child($1, decl);
        $$ = $1;

        free($3);
    }
    ;

exprList:
    /* vacío */ {
        $$ = create_node(NODE_EXPR_LIST, NULL);
    }
    | expr {
        $$ = create_node(NODE_EXPR_LIST, NULL);
        add_child($$, $1);
    }
    | exprList COMMA expr {
        $$ = $1;
        add_child($$, $3);
    }
    ;

block:
    LBRACE RBRACE { $$ = create_node(NODE_BLOCK, NULL); }
    | LBRACE statementList RBRACE { $$ = $2; }
    ;

statementList:
    statement { 
        $$ = create_node(NODE_BLOCK, NULL); 
        add_child($$, $1); 
    }
    | statementList statement { 
        add_child($1, $2); 
        $$ = $1; 
    }
    ;

statement:
    block { $$ = $1; }
    | IF LPAREN expr RPAREN statement %prec IFX {
        $$ = create_node(NODE_IF, NULL);
        add_child($$, $3);
        add_child($$, $5);
    }
    | IF LPAREN expr RPAREN statement ELSE statement {
        $$ = create_node(NODE_IF, NULL);
        add_child($$, $3);
        add_child($$, $5);
        add_child($$, $7);
    }
    | WHILE LPAREN expr RPAREN statement {
        $$ = create_node(NODE_WHILE, NULL);
        add_child($$, $3);
        add_child($$, $5);
    }
    | DO block WHILE LPAREN expr RPAREN SEMICOLON {
        $$ = create_node(NODE_DO_WHILE, NULL);
        add_child($$, $2);
        add_child($$, $5);
    }
    | BREAK SEMICOLON { $$ = create_node(NODE_BREAK, NULL); }
    | expr SEMICOLON { $$ = $1; }
    | typeRef IDENTIFIER optVarAssign varDeclTail SEMICOLON {
    $$ = create_node(NODE_VAR_DECL, NULL);

    // Tipo declarado
    add_child($$, $1);

    // Primera variable de la lista
    ASTNode* first = create_node(NODE_IDENTIFIER, $2);

    if ($3 != NULL) {
        add_child(first, $3);
    }

    // Insertar primera variable al inicio de la lista
    ASTNode* declarations = create_node(NODE_DECL_LIST, NULL);
    add_child(declarations, first);

    // Incorporar las variables adicionales
    if ($4 != NULL) {
        for (int i = 0; i < $4->child_count; i++) {
            add_child(declarations, $4->children[i]);
        }

        // Transferimos la propiedad de los hijos.
        // Evitamos que se liberen dos veces.
        free($4->children);
        $4->children = NULL;
        $4->child_count = 0;
        free_ast($4);
    }

    add_child($$, declarations);

    free($2);
    }
    ;

expr:
    IDENTIFIER {
        $$ = create_node(NODE_IDENTIFIER, $1);
        free($1);
    }
    | LITERAL_DEC { $$ = create_node(NODE_LITERAL, $1); free($1); }
    | LITERAL_HEX { $$ = create_node(NODE_LITERAL, $1); free($1); }
    | LITERAL_BITS { $$ = create_node(NODE_LITERAL, $1); free($1); }
    | LITERAL_STR { $$ = create_node(NODE_LITERAL, $1); free($1); }
    | LITERAL_CHAR { $$ = create_node(NODE_LITERAL, $1); free($1); }
    | LITERAL_BOOL { $$ = create_node(NODE_LITERAL, $1); free($1); }
    | expr OP_EQ expr     { $$ = create_binary_node(NODE_BINARY_OP, "==", $1, $3); free($2); }
    | expr OP_NEQ expr    { $$ = create_binary_node(NODE_BINARY_OP, "!=", $1, $3); free($2); }
    | expr OP_LE expr     { $$ = create_binary_node(NODE_BINARY_OP, "<=", $1, $3); free($2); }
    | expr OP_GE expr     { $$ = create_binary_node(NODE_BINARY_OP, ">=", $1, $3); free($2); }
    | expr OP_LT expr     { $$ = create_binary_node(NODE_BINARY_OP, "<",  $1, $3); free($2); }
    | expr OP_GT expr     { $$ = create_binary_node(NODE_BINARY_OP, ">",  $1, $3); free($2); }
    | expr OP_AND expr    { $$ = create_binary_node(NODE_BINARY_OP, "&&", $1, $3); free($2); }
    | expr OP_OR expr     { $$ = create_binary_node(NODE_BINARY_OP, "||", $1, $3); free($2); }
    | expr OP_PLUS expr   { $$ = create_binary_node(NODE_BINARY_OP, "+",  $1, $3); free($2); }
    | expr OP_MINUS expr  { $$ = create_binary_node(NODE_BINARY_OP, "-",  $1, $3); free($2); }
    | expr OP_MUL expr    { $$ = create_binary_node(NODE_BINARY_OP, "*",  $1, $3); free($2); }
    | expr OP_DIV expr    { $$ = create_binary_node(NODE_BINARY_OP, "/",  $1, $3); free($2); }
    | expr OP_MOD expr    { $$ = create_binary_node(NODE_BINARY_OP, "%",  $1, $3); free($2); }
    | expr OP_ASSIGN expr { $$ = create_binary_node(NODE_BINARY_OP, "=", $1, $3); free($2); }
    | OP_NOT expr         { $$ = create_binary_node(NODE_UNARY_OP, "!", $2, NULL); free($1); }
    | OP_MINUS expr       { $$ = create_binary_node(NODE_UNARY_OP, "-", $2, NULL); free($1); }
    | LPAREN expr RPAREN  { $$ = $2; }
    | expr LPAREN exprList RPAREN {
        $$ = create_node(NODE_CALL, NULL);
        add_child($$, $1);
        if ($3 != NULL) add_child($$, $3);
    }
    | expr LBRACKET expr RBRACKET {
        $$ = create_node(NODE_INDEXER, NULL);
        add_child($$, $1);
        add_child($$, $3);
    }
    ;

typeRef:
    KW_BOOL   { $$ = create_node(NODE_LITERAL, "bool"); }
    | KW_BYTE   { $$ = create_node(NODE_LITERAL, "byte"); }
    | KW_INT    { $$ = create_node(NODE_LITERAL, "int"); }
    | KW_UINT   { $$ = create_node(NODE_LITERAL, "uint"); }
    | KW_LONG   { $$ = create_node(NODE_LITERAL, "long"); }
    | KW_ULONG  { $$ = create_node(NODE_LITERAL, "ulong"); }
    | KW_CHAR   { $$ = create_node(NODE_LITERAL, "char"); }
    | KW_STRING { $$ = create_node(NODE_LITERAL, "string"); }
    | IDENTIFIER { $$ = create_node(NODE_IDENTIFIER, $1); free($1); }
    ;

%%

void yyerror(void* scanner, ParseContext* ctx, const char* s) {
    (void)scanner;
    if (ctx != NULL && ctx->errors != NULL) {
        error_list_add(ctx->errors, 0, s);
    }
    if (ctx != NULL) {
        ctx->has_error = 1;
    }
}