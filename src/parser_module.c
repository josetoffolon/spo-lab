#include "parser_module.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* --- Tipos y declaraciones de Flex (reentrante) ---
 * yyscan_t es equivalente a void* en Flex, pero lo declaramos
 * para que las firmas coincidan exactamente con lo que genera. */
typedef void* yyscan_t;

/* Funciones generadas por Flex */
int yylex_init(yyscan_t* scanner);
int yylex_destroy(yyscan_t scanner);
void* yy_scan_string(const char* str, yyscan_t scanner);
void yy_delete_buffer(void* buffer, yyscan_t scanner);

/* Funciones generadas por Bison */
int yyparse(void* scanner, ParseContext* ctx);

// --- Funciones de la lista de errores ---

ErrorList* error_list_create(void) {
    ErrorList* list = (ErrorList*)calloc(1, sizeof(ErrorList));
    return list;
}

void error_list_add(ErrorList* list, int line, const char* message) {
    if (list == NULL || message == NULL) return;

    ParseError* err = (ParseError*)malloc(sizeof(ParseError));
    if (err == NULL) return;

    err->line = line;
    err->message = strdup(message);
    err->next = NULL;

    if (list->tail == NULL) {
        list->head = err;
        list->tail = err;
    } else {
        list->tail->next = err;
        list->tail = err;
    }
    list->count++;
}

void error_list_free(ErrorList* list) {
    if (list == NULL) return;

    ParseError* current = list->head;
    while (current != NULL) {
        ParseError* next = current->next;
        free(current->message);
        free(current);
        current = next;
    }
    free(list);
}

// --- Función principal del módulo (Requisito 3) ---

ASTNode* parse_text(const char* text, ErrorList* errors) {
    if (text == NULL) return NULL;

    // 1. Creamos el contexto (pasamos el estado explícitamente)
    ParseContext ctx;
    ctx.root = NULL;
    ctx.errors = errors;
    ctx.has_error = 0;

    // 2. Inicializamos el scanner reentrante de Flex
    yyscan_t scanner = NULL;
    if (yylex_init(&scanner) != 0) {
        error_list_add(errors, 0, "No se pudo inicializar el lexer");
        return NULL;
    }

    // 3. Asociamos la cadena de texto al scanner
    void* buffer = yy_scan_string(text, scanner);
    if (buffer == NULL) {
        yylex_destroy(scanner);
        error_list_add(errors, 0, "No se pudo crear el buffer de análisis");
        return NULL;
    }

    // 4. Ejecutamos el parser (le pasamos el contexto y el scanner)
    int result = yyparse(scanner, &ctx);

    // 5. Limpieza de recursos del lexer (¡sin fugas!)
    yy_delete_buffer(buffer, scanner);
    yylex_destroy(scanner);

    // 6. Si hubo error sintáctico, liberamos el AST parcial
    if (result != 0) {
        if (ctx.root != NULL) {
            free_ast(ctx.root);
        }
        return NULL;
    }

    return ctx.root;
}

// --- Exportación a DOT (Graphviz) ---

static void dot_print_node(ASTNode* node, FILE* out, int* counter) {
    if (node == NULL) return;

    int my_id = (*counter)++;

    // Imprimimos el nodo con su etiqueta
    const char* label = node->value ? node->value : "?";
    switch (node->type) {
        case NODE_PROGRAM:    fprintf(out, "  n%d [label=\"PROGRAM\"];\n", my_id); break;
        case NODE_FUNC_DEF:   fprintf(out, "  n%d [label=\"FUNC: %s\"];\n", my_id, label); break;
        case NODE_VAR_DECL:   fprintf(out, "  n%d [label=\"VAR: %s\"];\n", my_id, label); break;
        case NODE_IF:         fprintf(out, "  n%d [label=\"IF\"];\n", my_id); break;
        case NODE_WHILE:      fprintf(out, "  n%d [label=\"WHILE\"];\n", my_id); break;
        case NODE_DO_WHILE:   fprintf(out, "  n%d [label=\"DO-WHILE\"];\n", my_id); break;
        case NODE_BLOCK:      fprintf(out, "  n%d [label=\"BLOCK\"];\n", my_id); break;
        case NODE_BREAK:      fprintf(out, "  n%d [label=\"BREAK\"];\n", my_id); break;
        case NODE_BINARY_OP:  fprintf(out, "  n%d [label=\"OP: %s\"];\n", my_id, label); break;
        case NODE_UNARY_OP:   fprintf(out, "  n%d [label=\"UNOP: %s\"];\n", my_id, label); break;
        case NODE_CALL:       fprintf(out, "  n%d [label=\"CALL\"];\n", my_id); break;
        case NODE_INDEXER:    fprintf(out, "  n%d [label=\"INDEX\"];\n", my_id); break;
        case NODE_IDENTIFIER: fprintf(out, "  n%d [label=\"ID: %s\"];\n", my_id, label); break;
        case NODE_LITERAL:    fprintf(out, "  n%d [label=\"LIT: %s\"];\n", my_id, label); break;
        default:              fprintf(out, "  n%d [label=\"?\"];\n", my_id); break;
    }

    // Hijos izquierdo/derecho
    if (node->left != NULL) {
        int child_id = *counter;
        dot_print_node(node->left, out, counter);
        fprintf(out, "  n%d -> n%d;\n", my_id, child_id);
    }
    if (node->right != NULL) {
        int child_id = *counter;
        dot_print_node(node->right, out, counter);
        fprintf(out, "  n%d -> n%d;\n", my_id, child_id);
    }

    // Lista de hijos
    for (int i = 0; i < node->child_count; i++) {
        int child_id = *counter;
        dot_print_node(node->children[i], out, counter);
        fprintf(out, "  n%d -> n%d;\n", my_id, child_id);
    }
}

void ast_to_dot(ASTNode* root, FILE* out) {
    if (root == NULL || out == NULL) return;
    fprintf(out, "digraph AST {\n");
    fprintf(out, "  node [shape=box, fontname=\"Helvetica\"];\n");
    int counter = 0;
    dot_print_node(root, out, &counter);
    fprintf(out, "}\n");
}