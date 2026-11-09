#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser_module.h"

// Lee un archivo completo por bloques (cumple regla "No byte a byte")
static char* read_file_block(const char* filename) {
    FILE* f = fopen(filename, "rb");
    if (f == NULL) return NULL;

    // Ir al final para saber el tamaño
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return NULL; }
    long size = ftell(f);
    if (size < 0) { fclose(f); return NULL; }
    if (fseek(f, 0, SEEK_SET) != 0) { fclose(f); return NULL; }

    char* buffer = (char*)malloc((size_t)size + 1);
    if (buffer == NULL) { fclose(f); return NULL; }

    // Leer en un solo bloque (o en bloques grandes si quisieras)
    size_t read_bytes = fread(buffer, 1, (size_t)size, f);
    buffer[read_bytes] = '\0';

    fclose(f);
    return buffer;
}

int main(int argc, char** argv) {
    if (argc != 3) {
        fprintf(stderr, "Uso: %s <archivo_entrada> <archivo_salida.dot>\n", argv[0]);
        return 1;
    }

    const char* input_file = argv[1];
    const char* output_file = argv[2];

    // 1. Leer archivo de entrada
    char* source = read_file_block(input_file);
    if (source == NULL) {
        fprintf(stderr, "Error: no se pudo leer '%s'\n", input_file);
        return 1;
    }

    // 2. Crear lista de errores
    ErrorList* errors = error_list_create();
    if (errors == NULL) {
        fprintf(stderr, "Error: no se pudo crear la lista de errores\n");
        free(source);
        return 1;
    }


    #ifdef AST_TEST_FAULT_INJECTION
    const char* inject = getenv("AST_TEST_FAIL_PLUS");

    if (inject != NULL && strcmp(inject, "1") == 0) {
        ast_test_fail_next_plus();
    }
    #endif


    // 3. Analizar el texto
    ASTNode* ast = parse_text(source, errors);

    // 4. Reportar errores (en stderr, NO en stdout - Requisito 4b)
    if (errors->count > 0) {
        fprintf(stderr, "Se encontraron %d error(es):\n", errors->count);
        ParseError* err = errors->head;
        while (err != NULL) {
            fprintf(stderr, "  [Linea %d] %s\n", err->line, err->message);
            err = err->next;
        }
    }

    // 5. Escribir el AST al archivo DOT si no hubo error
    if (ast != NULL) {
        FILE* out = fopen(output_file, "w");
        if (out == NULL) {
            fprintf(stderr, "Error: no se pudo crear '%s'\n", output_file);
            free_ast(ast);
            error_list_free(errors);
            free(source);
            return 1;
        }
        ast_to_dot(ast, out);
        fclose(out);
        printf("AST generado en: %s\n", output_file);
        free_ast(ast);
    }

    // 6. Determinar el estado de ejecución antes de liberar memoria
    int exit_code = (ast != NULL && errors->count == 0) ? 0 : 2;

    // 7. Liberar los recursos utilizados
    error_list_free(errors);
    free(source);

    return exit_code;
}