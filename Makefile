CC = gcc
CFLAGS = -g -Wall -Isrc -Ibuild
TARGET = build/parser
OBJS = build/parser.tab.o build/lex.yy.o build/ast.o build/parser_module.o build/main.o

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^

build/parser.tab.c build/parser.tab.h: src/parser.y
	@mkdir -p build
	bison -d -o build/parser.tab.c src/parser.y

build/lex.yy.c build/lex.yy.h: src/lexer.l build/parser.tab.h
	@mkdir -p build
	flex -o build/lex.yy.c src/lexer.l

build/%.o: build/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

build/%.o: src/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -rf build