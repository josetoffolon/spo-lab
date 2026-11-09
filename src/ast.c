#include "ast.h"
#include <stdio.h>
#include <string.h>
#include <limits.h>
#include <stdint.h>



#ifdef AST_TEST_FAULT_INJECTION
static int fail_next_create = 0;

void ast_test_fail_next_create(void) {
    fail_next_create = 1;
}
#endif

#ifdef AST_TEST_FAULT_INJECTION
    static int fail_next_plus = 0;

    void ast_test_fail_next_plus(void) {
        fail_next_plus = 1;
    }
#endif


// Crea un nodo genérico. Duplica el valor para que el nodo sea dueño de su memoria.
ASTNode* create_node(NodeType type, char* value) {
    #ifdef AST_TEST_FAULT_INJECTION
        if (fail_next_create) {
            fail_next_create = 0;
            return NULL;
        }
    #endif


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
    #ifdef AST_TEST_FAULT_INJECTION
        if (fail_next_plus &&
            type == NODE_BINARY_OP &&
            op != NULL &&
            strcmp(op, "+") == 0) {

            fail_next_plus = 0;
            return NULL;
        }
    #endif

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

ASTNode* create_list_node(
    NodeType type,
    ASTNode* first_child
) {
    ASTNode* list = create_node(type, NULL);

    if (list == NULL) {
        return NULL;
    }

    if (first_child != NULL) {
        if (!add_child(list, first_child)) {
            free_ast(list);
            return NULL;
        }
    }

    return list;
}

ASTNode* create_var_declaration(
    ASTNode* type,
    const char* first_name,
    ASTNode* initializer,
    ASTNode* additional_declarations
) {
    if (type == NULL || first_name == NULL) {
        return NULL;
    }

    size_t extra = 0;

    if (additional_declarations != NULL) {
        if (additional_declarations->type != NODE_DECL_LIST ||
            additional_declarations->child_count < 0) {
            return NULL;
        }

        extra = (size_t)additional_declarations->child_count;

        if (extra > 0 &&
            additional_declarations->children == NULL) {
            return NULL;
        }
    }

    if (extra >= (size_t)INT_MAX ||
        extra > SIZE_MAX / sizeof(ASTNode*) - 1) {
        return NULL;
    }

    // Crear nodos nuevos sin adquirir todavía
    // la propiedad de los argumentos recibidos.
    ASTNode* declaration = create_node(
        NODE_VAR_DECL, NULL
    );

    ASTNode* first = create_node(
        NODE_IDENTIFIER, (char*)first_name
    );

    ASTNode* declarations = create_node(
        NODE_DECL_LIST, NULL
    );

    if (!declaration || !first || !declarations) {
        goto fail;
    }

    // Reservar toda la memoria antes de transferir
    // cualquier nodo existente.
    declaration->children = malloc(
        2 * sizeof(ASTNode*)
    );

    declarations->children = malloc(
        (extra + 1) * sizeof(ASTNode*)
    );

    if (initializer != NULL) {
        first->children = malloc(sizeof(ASTNode*));
    }

    if (!declaration->children ||
        !declarations->children ||
        (initializer != NULL && !first->children)) {
        goto fail;
    }

    // A partir de aquí no se realizan asignaciones.
    // Comienza la transferencia de propiedad.

    if (initializer != NULL) {
        first->children[0] = initializer;
        first->child_count = 1;
    }

    declarations->children[0] = first;

    if (extra > 0) {
        memcpy(
            declarations->children + 1,
            additional_declarations->children,
            extra * sizeof(ASTNode*)
        );
    }

    declarations->child_count = (int)(extra + 1);

    declaration->children[0] = type;
    declaration->children[1] = declarations;
    declaration->child_count = 2;

    // La lista temporal entrega sus hijos.
    if (additional_declarations != NULL) {
        free(additional_declarations->children);
        additional_declarations->children = NULL;
        additional_declarations->child_count = 0;
        free_ast(additional_declarations);
    }

    return declaration;

fail:
    // Estos nodos todavía no poseen los argumentos.
    // Sus contadores de hijos siguen en cero.
    free_ast(declarations);
    free_ast(first);
    free_ast(declaration);

    return NULL;
}

int append_variable_declaration(ASTNode* list, const char* name, ASTNode* initializer) {
    if (list == NULL ||
        list->type != NODE_DECL_LIST ||
        name == NULL) {
        return 0;
    }

    ASTNode* variable = create_node(
        NODE_IDENTIFIER, (char*)name
    );

    if (variable == NULL) {
        return 0;
    }

    if (initializer != NULL) {
        if (!add_child(variable, initializer)) {
            free_ast(variable);
            return 0;
        }
    }

    if (!add_child(list, variable)) {
        // No liberar initializer, porque sigue
        // perteneciendo al llamador.
        if (initializer != NULL) {
            variable->child_count = 0;
        }

        free_ast(variable);
        return 0;
    }

    return 1;
}
