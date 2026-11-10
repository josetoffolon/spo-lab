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


#define AST_BUILD_TYPE(OUT, TYPE_NAME) do { \
    ASTNode* type_node = create_node( \
        NODE_LITERAL, (TYPE_NAME) \
    ); \
    if (type_node == NULL) { \
        yyerror(scanner, ctx, \
            "Error de memoria al crear tipo"); \
        YYABORT; \
    } \
    (OUT) = type_node; \
} while (0)

#define AST_BUILD_VALUE(OUT, NODE_KIND, TOKEN) do { \
    ASTNode* value_node = create_node( \
        (NODE_KIND), (TOKEN) \
    ); \
    if (value_node == NULL) { \
        free(TOKEN); \
        yyerror(scanner, ctx, \
            "Error de memoria al crear valor"); \
        YYABORT; \
    } \
    free(TOKEN); \
    (OUT) = value_node; \
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

        if ($$ == NULL) {
            yyerror(scanner, ctx,
                "Error de memoria al crear programa");
            YYABORT;
        }
    }

    | source sourceItem {
        if (!add_child($1, $2)) {
            free_ast($1);
            free_ast($2);

            yyerror(scanner, ctx,
                "Error de memoria al agregar funcion al programa");
            YYABORT;
        }

        $$ = $1;
    }
    ;

sourceItem:
    funcDef { $$ = $1; }
    ;

funcDef:
    funcSignature block {
        if (!add_child($1, $2)) {
            free_ast($1);
            free_ast($2);

            yyerror(
                scanner,
                ctx,
                "Error de memoria al agregar bloque a funcion"
            );

            YYABORT;
        }

        $$ = $1;
    }

    | funcSignature SEMICOLON {
        $$ = $1;
    }
    ;

funcSignature:
    IDENTIFIER LPAREN argList RPAREN {
        ASTNode* function = create_function_signature(
            $1, NULL, $3
        );

        if (function == NULL) {
            free($1);
            free_ast($3);

            yyerror(scanner, ctx,
                "Error de memoria al crear firma de funcion");
            YYABORT;
        }

        free($1);
        $$ = function;
    }

    | typeRef IDENTIFIER LPAREN argList RPAREN {
        ASTNode* function = create_function_signature(
            $2, $1, $4
        );

        if (function == NULL) {
            free_ast($1);
            free($2);
            free_ast($4);

            yyerror(scanner, ctx,
                "Error de memoria al crear firma de funcion");
            YYABORT;
        }

        free($2);
        $$ = function;
    }
    ;

argList:
    %empty {
        ASTNode* list = create_list_node(
            NODE_ARG_LIST, NULL
        );

        if (list == NULL) {
            yyerror(scanner, ctx,
                "Error de memoria al crear lista de argumentos");
            YYABORT;
        }

        $$ = list;
    }

    | argDef {
        ASTNode* list = create_list_node(
            NODE_ARG_LIST, $1
        );

        if (list == NULL) {
            free_ast($1);

            yyerror(scanner, ctx,
                "Error de memoria al crear lista de argumentos");
            YYABORT;
        }

        $$ = list;
    }

    | argList COMMA argDef {
        if (!add_child($1, $3)) {
            free_ast($1);
            free_ast($3);

            yyerror(scanner, ctx,
                "Error de memoria al agregar argumento");
            YYABORT;
        }

        $$ = $1;
    }
    ;


argDef:
    IDENTIFIER {
        ASTNode* argument = create_node(
            NODE_IDENTIFIER, $1
        );

        if (argument == NULL) {
            free($1);

            yyerror(scanner, ctx,
                "Error de memoria al crear argumento");
            YYABORT;
        }

        free($1);
        $$ = argument;
    }

    | typeRef IDENTIFIER {
        ASTNode* argument = create_node(
            NODE_IDENTIFIER, $2
        );

        if (argument == NULL) {
            free_ast($1);
            free($2);

            yyerror(scanner, ctx,
                "Error de memoria al crear argumento tipado");
            YYABORT;
        }

        if (!add_child(argument, $1)) {
            free_ast(argument);
            free_ast($1);
            free($2);

            yyerror(scanner, ctx,
                "Error de memoria al agregar tipo al argumento");
            YYABORT;
        }

        free($2);
        $$ = argument;
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
    %empty {
        $$ = create_node(NODE_DECL_LIST, NULL);

        if ($$ == NULL) {
            yyerror(
                scanner,
                ctx,
                "Error de memoria al crear lista de declaraciones"
            );
            YYABORT;
        }
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
    %empty {
        $$ = create_list_node(NODE_EXPR_LIST, NULL);

        if ($$ == NULL) {
            yyerror(scanner, ctx,
                "Error de memoria al crear lista de expresiones");
            YYABORT;
        }
    }

    | expr {
        ASTNode* list = create_list_node(
            NODE_EXPR_LIST, $1
        );

        if (list == NULL) {
            free_ast($1);

            yyerror(scanner, ctx,
                "Error de memoria al crear lista de expresiones");
            YYABORT;
        }

        $$ = list;
    }

    | exprList COMMA expr {
        if (!add_child($1, $3)) {
            free_ast($1);
            free_ast($3);

            yyerror(scanner, ctx,
                "Error de memoria al agregar expresion");
            YYABORT;
        }

        $$ = $1;
    }
    ;


block:
    LBRACE RBRACE {
        $$ = create_node(NODE_BLOCK, NULL);

        if ($$ == NULL) {
            yyerror(
                scanner,
                ctx,
                "Error de memoria al crear bloque vacio"
            );
            YYABORT;
        }
    }

    | LBRACE statementList RBRACE {
        $$ = $2;
    }
    ;


statementList:
    statement {
        ASTNode* block = create_list_node(
            NODE_BLOCK, $1
        );

        if (block == NULL) {
            free_ast($1);

            yyerror(scanner, ctx,
                "Error de memoria al crear bloque");
            YYABORT;
        }

        $$ = block;
    }

    
    | statementList statement {

        #ifdef AST_TEST_FAULT_INJECTION
            /*
            * Prueba controlada: provocar un fallo
            * justo antes de agregar una instrucción.
            */
            if (getenv("AST_TEST_FAIL_STATEMENT_ADD") != NULL) {
                ast_test_fail_next_add_child();
            }
        #endif

        if (!add_child($1, $2)) {
            free_ast($1);
            free_ast($2);

            yyerror(
                scanner,
                ctx,
                "Error de memoria al agregar instruccion"
            );

            YYABORT;
        }

    $$ = $1;

    }
    ;

statement:
    block { $$ = $1; }
    | IF LPAREN expr RPAREN statement %prec IFX {
        ASTNode* node = create_control_node(
            NODE_IF, $3, $5, NULL
        );

        if (node == NULL) {
            free_ast($3);
            free_ast($5);
            yyerror(scanner, ctx,
                "Error de memoria al crear if");
            YYABORT;
        }

        $$ = node;
    }

    | IF LPAREN expr RPAREN statement ELSE statement {
        ASTNode* node = create_control_node(
            NODE_IF, $3, $5, $7
        );

        if (node == NULL) {
            free_ast($3);
            free_ast($5);
            free_ast($7);
            yyerror(scanner, ctx,
                "Error de memoria al crear if-else");
            YYABORT;
        }

        $$ = node;
    }

    | WHILE LPAREN expr RPAREN statement {
        ASTNode* node = create_control_node(
            NODE_WHILE, $3, $5, NULL
        );

        if (node == NULL) {
            free_ast($3);
            free_ast($5);
            yyerror(scanner, ctx,
                "Error de memoria al crear while");
            YYABORT;
        }

        $$ = node;
    }

    | DO block WHILE LPAREN expr RPAREN SEMICOLON {
        ASTNode* node = create_control_node(
            NODE_DO_WHILE, $2, $5, NULL
        );

        if (node == NULL) {
            free_ast($2);
            free_ast($5);
            yyerror(scanner, ctx,
                "Error de memoria al crear do-while");
            YYABORT;
        }

        $$ = node;
    }

    | BREAK SEMICOLON {
        $$ = create_node(NODE_BREAK, NULL);

        if ($$ == NULL) {
            yyerror(
                scanner,
                ctx,
                "Error de memoria al crear break"
            );
            YYABORT;
        }
    }
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
        AST_BUILD_VALUE($$, NODE_IDENTIFIER, $1);
    }
    | LITERAL_DEC {
        AST_BUILD_VALUE($$, NODE_LITERAL, $1);
    }
    | LITERAL_HEX {
        AST_BUILD_VALUE($$, NODE_LITERAL, $1);
    }
    | LITERAL_BITS {
        AST_BUILD_VALUE($$, NODE_LITERAL, $1);
    }
    | LITERAL_STR {
        AST_BUILD_VALUE($$, NODE_LITERAL, $1);
    }
    | LITERAL_CHAR {
        AST_BUILD_VALUE($$, NODE_LITERAL, $1);
    }
    | LITERAL_BOOL {
        AST_BUILD_VALUE($$, NODE_LITERAL, $1);
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

    
    | expr LPAREN exprList RPAREN {
        ASTNode* node = create_postfix_node(
            NODE_CALL, $1, $3
        );

        if (node == NULL) {
            free_ast($1);
            free_ast($3);

            yyerror(scanner, ctx,
                "Error de memoria al crear llamada");
            YYABORT;
        }

        $$ = node;
    }

    | expr LBRACKET exprList RBRACKET {
        ASTNode* node = create_postfix_node(
            NODE_INDEXER, $1, $3
        );

        if (node == NULL) {
            free_ast($1);
            free_ast($3);

            yyerror(scanner, ctx,
                "Error de memoria al crear indexador");
            YYABORT;
        }

        $$ = node;
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
        AST_BUILD_TYPE($$, "bool");
    }
    | KW_BYTE {
        AST_BUILD_TYPE($$, "byte");
    }
    | KW_INT {
        AST_BUILD_TYPE($$, "int");
    }
    | KW_UINT {
        AST_BUILD_TYPE($$, "uint");
    }
    | KW_LONG {
        AST_BUILD_TYPE($$, "long");
    }
    | KW_ULONG {
        AST_BUILD_TYPE($$, "ulong");
    }
    | KW_CHAR {
        AST_BUILD_TYPE($$, "char");
    }
    | KW_STRING {
        AST_BUILD_TYPE($$, "string");
    }

    | IDENTIFIER {
        ASTNode* type_node = create_node(
            NODE_IDENTIFIER, $1
        );

        if (type_node == NULL) {
            free($1);

            yyerror(scanner, ctx,
                "Error de memoria al crear tipo personalizado");
            YYABORT;
        }

        free($1);
        $$ = type_node;
    }

    | typeRef LBRACKET arrayCommas RBRACKET {
        char dimensions[32];

        int written = snprintf(
            dimensions,
            sizeof(dimensions),
            "%d",
            $3 + 1
        );

        if (written < 0 ||
            (size_t)written >= sizeof(dimensions)) {
            free_ast($1);

            yyerror(scanner, ctx,
                "Error al representar dimensiones");
            YYABORT;
        }

        ASTNode* array_node = create_node(
            NODE_ARRAY_TYPE, dimensions
        );

        if (array_node == NULL) {
            free_ast($1);

            yyerror(scanner, ctx,
                "Error de memoria al crear arreglo");
            YYABORT;
        }

        if (!add_child(array_node, $1)) {
            free_ast(array_node);
            free_ast($1);

            yyerror(scanner, ctx,
                "Error de memoria al agregar tipo base");
            YYABORT;
        }

        $$ = array_node;
    }
    ;

%%

void yyerror(void* scanner, ParseContext* ctx, const char* message) {
    if (ctx ->has_error) {
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
