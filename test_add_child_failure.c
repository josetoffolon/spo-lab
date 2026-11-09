
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "ast.h"

int main(void) {
    ASTNode* parent = create_node(
        NODE_BLOCK, NULL
    );

    ASTNode* child = create_node(
        NODE_LITERAL, "42"
    );

    assert(parent != NULL);
    assert(child != NULL);

    ast_test_fail_next_add_child();

    int result = add_child(parent, child);

    // La operación debe fallar.
    assert(result == 0);

    // El padre no debe adquirir el hijo.
    assert(parent->child_count == 0);

    // El hijo sigue siendo válido.
    assert(strcmp(child->value, "42") == 0);

    // La propiedad permanece con el llamador.
    free_ast(child);
    free_ast(parent);

    puts("add_child failure: OK");
    return 0;
}
