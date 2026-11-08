#ifndef AST_H
#define AST_H

#include <stdlib.h>

// Tipos de nodos del AST (Variante 1)

typedef enum {
    NODE_PROGRAM,
    NODE_FUNC_DEF,
    NODE_VAR_DECL,
    NODE_IF,
    NODE_WHILE,
    NODE_DO_WHILE,
    NODE_BLOCK,
    NODE_BREAK,
    NODE_BINARY_OP,
    NODE_UNARY_OP,
    NODE_CALL,
    NODE_INDEXER,
    NODE_IDENTIFIER,
    NODE_LITERAL,
    NODE_ARG_LIST,
    NODE_EXPR_LIST,
    NODE_DECL_LIST,
    NODE_ARRAY_TYPE
} NodeType;


typedef struct ASTNode {
    NodeType type;
    char* value;            // Para identificadores, literales, operadores
    struct ASTNode* left;
    struct ASTNode* right;
    struct ASTNode** children; // Para listas (argumentos, statements)
    int child_count;
} ASTNode;

int move_children(ASTNode* destination, ASTNode* source);

/*
 * Construye una declaración de variables.
 *
 * Éxito:
 *   Devuelve NODE_VAR_DECL y adquiere type,
 *   initializer y additional_declarations.
 *
 * Fallo:
 *   Devuelve NULL y deja intactos esos argumentos.
 *
 * first_name es prestado: la función lo copia.
 */
ASTNode* create_var_declaration(
    ASTNode* type,
    const char* first_name,
    ASTNode* initializer,
    ASTNode* additional_declarations
);


// Funciones para crear nodos (evitan fugas de memoria)
ASTNode* create_node(NodeType type, char* value);
ASTNode* create_binary_node(NodeType type, char* op, ASTNode* left, ASTNode* right);
int add_child(ASTNode* parent, ASTNode* child);
void free_ast(ASTNode* node);

#endif