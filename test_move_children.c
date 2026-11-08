
#include <assert.h>
#include <stdio.h>
#include "ast.h"

int main(void) {
    ASTNode* source = create_node(NODE_DECL_LIST, NULL);
    ASTNode* destination = create_node(NODE_DECL_LIST, NULL);
    ASTNode* a = create_node(NODE_IDENTIFIER, "a");
    ASTNode* b = create_node(NODE_IDENTIFIER, "b");

    assert(source && destination && a && b);
    assert(add_child(source, a));
    assert(add_child(source, b));

    assert(move_children(destination, source));

    // El destino ahora posee ambos hijos.
    assert(destination->child_count == 2);
    assert(destination->children[0] == a);
    assert(destination->children[1] == b);

    // El origen ya no posee esos hijos.
    assert(source->child_count == 0);
    assert(source->children == NULL);

    // No puede transferirse una lista a sí misma.
    assert(move_children(destination, destination) == 0);

    // No acepta punteros nulos.
    assert(move_children(NULL, source) == 0);
    assert(move_children(destination, NULL) == 0);

    // Los árboles deben conservar su estado.
    assert(destination->child_count == 2);
    assert(source->child_count == 0);

    free_ast(source);
    free_ast(destination);

    puts("move_children: OK");
    return 0;
}
