
#include <assert.h>
#include <stdio.h>
#include "ast.h"

int main(void) {
    ASTNode* child = create_node(
        NODE_LITERAL, "10"
    );

    assert(child != NULL);

    ASTNode* list = create_list_node(
        NODE_EXPR_LIST, child
    );

    assert(list != NULL);
    assert(list->type == NODE_EXPR_LIST);
    assert(list->child_count == 1);
    assert(list->children[0] == child);

    free_ast(list);

    ASTNode* empty = create_list_node(
        NODE_ARG_LIST, NULL
    );

    assert(empty != NULL);
    assert(empty->child_count == 0);

    free_ast(empty);

    puts("create_list_node: OK");
    return 0;
}
