
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "ast.h"

int main(void) {
    ASTNode* type = create_node(
        NODE_LITERAL, "int"
    );

    ASTNode* initializer = create_node(
        NODE_LITERAL, "10"
    );

    ASTNode* additional = create_node(
        NODE_DECL_LIST, NULL
    );

    ASTNode* b = create_node(
        NODE_IDENTIFIER, "b"
    );

    ASTNode* c = create_node(
        NODE_IDENTIFIER, "c"
    );

    assert(type && initializer && additional && b && c);

    assert(add_child(additional, b));
    assert(add_child(additional, c));

    ASTNode* declaration = create_var_declaration(
        type, "a", initializer, additional
    );

    assert(declaration != NULL);
    assert(declaration->type == NODE_VAR_DECL);
    assert(declaration->child_count == 2);

    ASTNode* variables = declaration->children[1];

    assert(variables->type == NODE_DECL_LIST);
    assert(variables->child_count == 3);

    assert(strcmp(
        variables->children[0]->value, "a"
    ) == 0);

    assert(strcmp(
        variables->children[1]->value, "b"
    ) == 0);

    assert(strcmp(
        variables->children[2]->value, "c"
    ) == 0);

    assert(variables->children[0]->child_count == 1);
    assert(variables->children[0]->children[0] == initializer);

    // Todos los argumentos AST pasaron a ser
    // propiedad del resultado.
    free_ast(declaration);


    // Una llamada inválida debe preservar
    // la propiedad de todos los argumentos.
    ASTNode* preserved_type = create_node(
        NODE_LITERAL, "string"
    );

    ASTNode* preserved_init = create_node(
        NODE_LITERAL, "\"Hola\""
    );

    assert(preserved_type && preserved_init);

    ASTNode* invalid = create_var_declaration(
        preserved_type,
        NULL,
        preserved_init,
        NULL
    );

    assert(invalid == NULL);
    assert(strcmp(preserved_type->value, "string") == 0);
    assert(strcmp(preserved_init->value, "\"Hola\"") == 0);

    free_ast(preserved_type);
    free_ast(preserved_init);

    puts("create_var_declaration: OK");
    return 0;
}
