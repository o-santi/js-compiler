all: saida entrada.js
	./saida < entrada.js

run: saida entrada.js
	./saida < entrada.js | ./mdp/interpretador 

saida: lex.yy.c y.tab.c
	g++ y.tab.c -o saida -lfl -Wall -Wextra -pedantic	

lex.yy.c: mini_js.lex
	lex mini_js.lex

y.tab.c: mini_js.y
	yacc mini_js.y -v 

clean: 
	rm -f lex.yy.c y.tab.c saida
