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

/*
 * Añade una variable a NODE_DECL_LIST.
 * Éxito: list adquiere initializer.
 * Fallo: list e initializer conservan su propiedad.
 */
int append_variable_declaration(
    ASTNode* list,
    const char* name,
    ASTNode* initializer
);

/*
 * Éxito: adquiere return_type y args.
 * Fallo: conserva la propiedad de ambos.
 * name es prestado y se copia.
 */
ASTNode* create_function_signature(
    const char* name,
    ASTNode* return_type,
    ASTNode* args
);

/*
 * Construye un nodo de estructura de control.
 *
 * Éxito:
 *   Adquiere la propiedad de first, second y third.
 *
 * Fallo:
 *   Conserva la propiedad de los argumentos.
 *
 * third puede ser NULL.
 */
ASTNode* create_control_node(
    NodeType type,
    ASTNode* first,
    ASTNode* second,
    ASTNode* third
);


/*
 * Construye una llamada o un indexador.
 *
 * Exito: adquiere first y second.
 * Fallo: conserva la propiedad de ambos.
 */
ASTNode* create_postfix_node(
    NodeType type,
    ASTNode* first,
    ASTNode* second
);


// Funciones para crear nodos (evitan fugas de memoria)
ASTNode* create_node(NodeType type, char* value);
ASTNode* create_binary_node(NodeType type, char* op, ASTNode* left, ASTNode* right);
int add_child(ASTNode* parent, ASTNode* child);
void free_ast(ASTNode* node);

ASTNode* create_list_node(
    NodeType type,
    ASTNode* first_child
);

#ifdef AST_TEST_FAULT_INJECTION
void ast_test_fail_next_create(void);
#endif


#ifdef AST_TEST_FAULT_INJECTION
void ast_test_fail_next_plus(void);
#endif

#ifdef AST_TEST_FAULT_INJECTION
void ast_test_fail_next_add_child(void);
#endif


#endif