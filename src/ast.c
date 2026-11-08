#include "ast.h"
#include <stdio.h>
#include <string.h>

// Crea un nodo genérico. Duplica el valor para que el nodo sea dueño de su memoria.
ASTNode* create_node(NodeType type, char* value) {
    ASTNode* node = calloc(1, sizeof(ASTNode));

    if (node == NULL) {
        return NULL;
    }

    node->type = type;

    if (value != NULL) {
        node->value = strdup(value);

        if (node->value == NULL) {
            free(node);
            return NULL;
        }
    }

    return node;
}


// Crea un nodo binario (ej. una operación a + b)
ASTNode* create_binary_node(NodeType type, char* op, ASTNode* left, ASTNode* right) {
    ASTNode* node = create_node(type, op);
    if (node == NULL) return NULL;
    node->left = left;
    node->right = right;
    return node;
}

// Añade un hijo a un nodo padre (realloc dinámico, no hay tamaño máximo)
int add_child(ASTNode* parent, ASTNode* child) {
    if (parent == NULL || child == NULL) {
        return 0;
    }

    ASTNode** new_children = realloc(
        parent->children,
        sizeof(ASTNode*) * (parent->child_count + 1)
    );

    if (new_children == NULL) {
        return 0;
    }

    parent->children = new_children;
    parent->children[parent->child_count] = child;
    parent->child_count++;

    return 1;
}


// Libera recursivamente todo el árbol (evita fugas de memoria)
void free_ast(ASTNode* node) {
    if (node == NULL) return;

    // Primero liberamos los hijos (post-orden)
    free_ast(node->left);
    free_ast(node->right);
    for (int i = 0; i < node->child_count; i++) {
        free_ast(node->children[i]);
    }

    free(node->children);
    free(node->value);
    free(node);
}