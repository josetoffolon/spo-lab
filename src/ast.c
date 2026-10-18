#include "ast.h"
#include <stdio.h>
#include <string.h>

// Crea un nodo genérico. Duplica el valor para que el nodo sea dueño de su memoria.
ASTNode* create_node(NodeType type, char* value) {
    ASTNode* node = (ASTNode*)malloc(sizeof(ASTNode));
    if (node == NULL) {
        return NULL; // Fallo al asignar memoria
    }
    node->type = type;
    node->value = (value != NULL) ? strdup(value) : NULL;
    node->left = NULL;
    node->right = NULL;
    node->children = NULL;
    node->child_count = 0;
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
void add_child(ASTNode* parent, ASTNode* child) {
    if (parent == NULL || child == NULL) return;

    // Reserva espacio para un puntero más
    ASTNode** new_children = (ASTNode**)realloc(
        parent->children,
        sizeof(ASTNode*) * (parent->child_count + 1)
    );
    if (new_children == NULL) return; // Fallo de realloc, no perdemos el original

    parent->children = new_children;
    parent->children[parent->child_count] = child;
    parent->child_count++;
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