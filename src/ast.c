#include "ast.h"
#include <stdio.h>
#include <string.h>
#include <limits.h>
#include <stdint.h>

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

int move_children(ASTNode* destination, ASTNode* source) {
    if (destination == NULL || source == NULL ||
        destination == source) {
        return 0;
    }

    if (destination->child_count < 0 ||
        source->child_count < 0) {
        return 0;
    }

    size_t dst_count = (size_t)destination->child_count;
    size_t src_count = (size_t)source->child_count;

    if (src_count == 0) {
        return 1;
    }

    if (src_count > (size_t)INT_MAX - dst_count) {
        return 0;
    }

    size_t total = dst_count + src_count;

    if (total > SIZE_MAX / sizeof(ASTNode*)) {
        return 0;
    }

    ASTNode** resized = realloc(
        destination->children,
        total * sizeof(ASTNode*)
    );

    if (resized == NULL) {
        return 0;
    }

    destination->children = resized;

    memcpy(
        destination->children + dst_count,
        source->children,
        src_count * sizeof(ASTNode*)
    );

    destination->child_count = (int)total;

    // La propiedad de todos los hijos pasa al destino.
    free(source->children);
    source->children = NULL;
    source->child_count = 0;

    return 1;
}