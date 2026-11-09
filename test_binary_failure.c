
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "ast.h"

int main(void) {
    ASTNode* left = create_node(
        NODE_LITERAL, "10"
    );

    ASTNode* right = create_node(
        NODE_LITERAL, "20"
    );

    assert(left != NULL);
    assert(right != NULL);

    // Simular el siguiente fallo de creación.
    ast_test_fail_next_create();

    ASTNode* expression = create_binary_node(
        NODE_BINARY_OP, "+", left, right
    );

    // El constructor debe informar del fallo.
    assert(expression == NULL);

    // Ningún operando debe haber sido liberado.
    assert(strcmp(left->value, "10") == 0);
    assert(strcmp(right->value, "20") == 0);

    // El llamador sigue siendo propietario.
    free_ast(left);
    free_ast(right);

    // Verificar que la siguiente creación funciona.
    ASTNode* recovered = create_node(
        NODE_LITERAL, "30"
    );

    assert(recovered != NULL);
    free_ast(recovered);

    puts("binary allocation failure: OK");
    return 0;
}
