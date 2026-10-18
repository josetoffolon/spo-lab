#ifndef PARSER_MODULE_H
#define PARSER_MODULE_H

#include <stdio.h>
#include "ast.h"

// Estructura de error (lista enlazada simple)
typedef struct ParseError {
    int line;
    char* message;
    struct ParseError* next;
} ParseError;

typedef struct {
    ParseError* head;
    ParseError* tail;
    int count;
} ErrorList;

// Contexto de parseo: es el "estado" que se pasa al parser puro
typedef struct {
    ASTNode* root;       // Raíz del AST resultante
    ErrorList* errors;   // Lista de errores
    int has_error;       // Bandera de error
} ParseContext;

// --- Funciones de la lista de errores ---
ErrorList* error_list_create(void);
void error_list_add(ErrorList* list, int line, const char* message);
void error_list_free(ErrorList* list);

// --- Interfaz principal del módulo ---
// Recibe texto, devuelve el AST (o NULL si falla) y llena la lista de errores
ASTNode* parse_text(const char* text, ErrorList* errors);

// --- Función para exportar el AST a formato DOT (Graphviz) ---
// La incluimos aquí porque es parte del módulo (opcional)
void ast_to_dot(ASTNode* root, FILE* out);

#endif