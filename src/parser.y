%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "parser_module.h"
int yyget_lineno(void* scanner);

#define AST_BUILD_BINARY(OUT, LEFT, TOKEN, RIGHT) do { \
    ASTNode* ast_result = create_binary_node( \
        NODE_BINARY_OP, (TOKEN), (LEFT), (RIGHT) \
    ); \
    if (ast_result == NULL) { \
        free_ast(LEFT); \
        free(TOKEN); \
        free_ast(RIGHT); \
        yyerror(scanner, ctx, \
            "Error de memoria al crear expresion binaria"); \
        YYABORT; \
    } \
    free(TOKEN); \
    (OUT) = ast_result; \
} while (0)

#define AST_BUILD_UNARY(OUT, TOKEN, OPERAND) do { \
    ASTNode* ast_result = create_binary_node( \
        NODE_UNARY_OP, (TOKEN), (OPERAND), NULL \
    ); \
    if (ast_result == NULL) { \
        free(TOKEN); \
        free_ast(OPERAND); \
        yyerror(scanner, ctx, \
            "Error de memoria al crear expresion unaria"); \
        YYABORT; \
    } \
    free(TOKEN); \
    (OUT) = ast_result; \
} while (0)

%}

%code requires {
    #include "ast.h"
    #include "parser_module.h"
}

%glr-parser
%define api.pure true

%lex-param   { void* scanner }
%parse-param { void* scanner }
%parse-param { ParseContext* ctx }



%union {
    char* str;
    ASTNode* node;
    int dimension_count;
}

/* Este bloque se inserta en parser.tab.h DESPUÉS de definir YYSTYPE */
%code provides {
    int yylex(YYSTYPE* yylval_param, void* yyscanner);
    void yyerror(void* scanner, ParseContext* ctx, const char* s);
}

%token <str> IDENTIFIER LITERAL_STR LITERAL_CHAR LITERAL_HEX LITERAL_BITS LITERAL_DEC LITERAL_BOOL
%token <str> OP_EQ OP_NEQ OP_LE OP_GE OP_AND OP_OR OP_PLUS OP_MINUS OP_MUL OP_DIV OP_MOD OP_ASSIGN OP_LT OP_GT OP_NOT
%token <str> OP_BIT_AND OP_BIT_OR OP_BIT_XOR OP_BIT_NOT
%token <str> OP_SHL OP_SHR
%token IF ELSE WHILE DO BREAK
%token KW_BOOL KW_BYTE KW_INT KW_UINT KW_LONG KW_ULONG KW_CHAR KW_STRING
%token LPAREN RPAREN LBRACE RBRACE LBRACKET RBRACKET SEMICOLON COMMA
%token INVALID

%type <node> source sourceItem funcDef funcSignature argList argDef statement statementList block expr typeRef exprList optVarAssign varDeclTail
%type <dimension_count> arrayCommas

%destructor { free($$); } <str>
%destructor { free_ast($$); } <node>



/* Precedencia de menor a mayor */

/* Asignación */
%right OP_ASSIGN

/* Operadores lógicos */
%left OP_OR
%left OP_AND

/* Operadores bit a bit */
%left OP_BIT_OR
%left OP_BIT_XOR
%left OP_BIT_AND

/* Comparación por igualdad */
%left OP_EQ OP_NEQ

/* Comparación relacional */
%left OP_LT OP_GT OP_LE OP_GE

/* Desplazamientos */
%left OP_SHL OP_SHR

/* Operaciones aritméticas */
%left OP_PLUS OP_MINUS
%left OP_MUL OP_DIV OP_MOD

/* Operadores unarios */
%precedence OP_NOT UMINUS UBITNOT

/* Operaciones postfijas */
%left LPAREN LBRACKET


/* Resolver el "dangling else" */
%nonassoc IFX
%nonassoc ELSE

%start input

%%

input:
    source {
        ctx->root = $1;
    }
    ;



source:
    %empty {
        $$ = create_node(NODE_PROGRAM, NULL);
    }
    | source sourceItem {
        $$ = $1;

        if ($$ != NULL && $2 != NULL) {
            add_child($$, $2);
        }
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
    %empty {
        $$ = NULL;
    }
    | OP_ASSIGN expr {
        free($1);
        $$ = $2;
    }
    ;

varDeclTail:
    /* vacío */ {
        $$ = create_node(NODE_DECL_LIST, NULL);
    }
    
    | varDeclTail COMMA IDENTIFIER optVarAssign {
        if (!append_variable_declaration($1, $3, $4)) {
            free_ast($1);
            free($3);
            free_ast($4);

            yyerror(
                scanner,
                ctx,
                "No se pudo agregar la variable"
            );

            YYABORT;
        }

    free($3);
    $$ = $1;
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
    ASTNode* declaration = create_var_declaration(
        $1, $2, $3, $4
    );

    if (declaration == NULL) {
        // La función conserva los argumentos al fallar.
        // Esta reducción debe liberarlos explícitamente.
        free_ast($1);
        free($2);
        free_ast($3);
        free_ast($4);

        yyerror(
            scanner,
            ctx,
            "No se pudo construir la declaracion"
        );

        YYABORT;
    }

    // La función ha adquirido todos los nodos AST.
    // El texto del identificador sigue siendo nuestro.
    free($2);

    $$ = declaration;
    }
    ;


expr:
    IDENTIFIER {
        $$ = create_node(NODE_IDENTIFIER, $1);
        free($1);
    }

    | LITERAL_DEC {
        $$ = create_node(NODE_LITERAL, $1);
        free($1);
    }
    | LITERAL_HEX {
        $$ = create_node(NODE_LITERAL, $1);
        free($1);
    }
    | LITERAL_BITS {
        $$ = create_node(NODE_LITERAL, $1);
        free($1);
    }
    | LITERAL_STR {
        $$ = create_node(NODE_LITERAL, $1);
        free($1);
    }
    | LITERAL_CHAR {
        $$ = create_node(NODE_LITERAL, $1);
        free($1);
    }
    | LITERAL_BOOL {
        $$ = create_node(NODE_LITERAL, $1);
        free($1);
    }

    /* Comparaciones */
    | expr OP_EQ expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }
    | expr OP_NEQ expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }
    | expr OP_LT expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }
    | expr OP_GT expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }
    | expr OP_LE expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }
    | expr OP_GE expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }

    /* Lógicos */
    | expr OP_AND expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }
    | expr OP_OR expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }

    /* Bit a bit */
    | expr OP_BIT_AND expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }
    | expr OP_BIT_OR expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }
    | expr OP_BIT_XOR expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }
    | expr OP_SHL expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }
    | expr OP_SHR expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }

    /* Aritméticos */
    | expr OP_PLUS expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }
    | expr OP_MINUS expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }
    | expr OP_MUL expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }
    | expr OP_DIV expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }
    | expr OP_MOD expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }

    /* Asignación */
    | expr OP_ASSIGN expr {
        AST_BUILD_BINARY($$, $1, $2, $3);
    }

    /* Unarios */
    | OP_MINUS expr %prec UMINUS {
        AST_BUILD_UNARY($$, $1, $2);
    }
    | OP_NOT expr {
        AST_BUILD_UNARY($$, $1, $2);
    }
    | OP_BIT_NOT expr %prec UBITNOT {
        AST_BUILD_UNARY($$, $1, $2);
    }

    /* Paréntesis */
    | LPAREN expr RPAREN {
        $$ = $2;
    }

    /* Llamadas */
    | expr LPAREN exprList RPAREN {
        $$ = create_node(NODE_CALL, NULL);
        add_child($$, $1);
        if ($3 != NULL) {
            add_child($$, $3);
        }
    }

    /* Indexación */
    | expr LBRACKET exprList RBRACKET {
        $$ = create_node(NODE_INDEXER, NULL);
        add_child($$, $1);
        add_child($$, $3);
    }
    ;


arrayCommas:
    %empty {
        $$ = 0;
    }
    | arrayCommas COMMA {
        $$ = $1 + 1;
    }
    ;


typeRef:
    KW_BOOL {
        $$ = create_node(NODE_LITERAL, "bool");
    }
    | KW_BYTE {
        $$ = create_node(NODE_LITERAL, "byte");
    }
    | KW_INT {
        $$ = create_node(NODE_LITERAL, "int");
    }
    | KW_UINT {
        $$ = create_node(NODE_LITERAL, "uint");
    }
    | KW_LONG {
        $$ = create_node(NODE_LITERAL, "long");
    }
    | KW_ULONG {
        $$ = create_node(NODE_LITERAL, "ulong");
    }
    | KW_CHAR {
        $$ = create_node(NODE_LITERAL, "char");
    }
    | KW_STRING {
        $$ = create_node(NODE_LITERAL, "string");
    }
    | IDENTIFIER {
        $$ = create_node(NODE_IDENTIFIER, $1);
        free($1);
    }
    | typeRef LBRACKET arrayCommas RBRACKET {
        char dimensions[32];

        snprintf(
            dimensions,
            sizeof(dimensions),
            "%d",
            $3 + 1
        );

        $$ = create_node(NODE_ARRAY_TYPE, dimensions);

        // El tipo base es hijo del arreglo
        add_child($$, $1);
    }
    ;

%%

void yyerror(
    void* scanner,
    ParseContext* ctx,
    const char* message
) {
    if (ctx == NULL) {
        return;
    }

    int line = scanner != NULL
        ? yyget_lineno(scanner)
        : 0;

    if (ctx->errors != NULL) {
        error_list_add(
            ctx->errors,
            line,
            message
        );
    }

    ctx->has_error = 1;
}
