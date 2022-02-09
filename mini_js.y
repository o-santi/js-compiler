%{
#include <iostream>
#include <string>
#include <map>
#include <vector>
  
using namespace std;

extern "C" int yylex();

struct Atributos {
  string str;
  int start;
  int end;
};

#define YYSTYPE Atributos

vector<string> stack;
void erro( string msg );
int push( string st );
void change_addr(int index, int addr);
string token_to_string (int token);

// protótipo para o analisador léxico (gerado pelo lex)
int yylex();
void yyerror( const char* );
 
%}

%token	ID 
        NUM
        STRING
        LET
        VAR
        CONST
        NEW_ARRAY
        NEW_OBJECT
        IF
        ELSE
        FOR
        WHILE 
        INC_OP
        DEC_OP
        COMPARE_OP

%start  STATEMENTS

%left '<' '>' '=' INC_OP DEC_OP COMPARE_OP
%left '+' '-'
%left '*' '/'
%left '%' '^'


%nonassoc IF
%nonassoc ELSE

// Lendo da esquerda para direita:
// $$ é símbolo do lado esquerdo
// $1 é o primeiro símbolo do lado direito
// $2 é o segundo símbolo do lado direito
// e assim por diante.

%%

STATEMENT : EXPRESSION ';' { $$.start = $1.start; $$.end = push("^");}
          | DECL_LET ';'
	  | BLOCK
	  | IF_STATEMENT
	  | FOR_STATEMENT
	  | WHILE_STATEMENT
          ;

BLOCK : '{' STATEMENTS '}' {$$ = $2;} ;
      

STATEMENTS : STATEMENT STATEMENTS {$$.start = $1.start; $$.end = $2.end;}
           | STATEMENT
           ;

LVALUE : ID { $$.start = $$.end = $1.start = $1.end = push($1.str);};

LVALUEPROP: EXPRESSION '[' EXPRESSION ']' {$$.start = $1.start; $$.end = $3.end;}
          | EXPRESSION '.' ID             {$$.start = $1.start; $$.end = $3.end = push($3.str);}
          ;

ASSIGN : LVALUE '=' EXPRESSION        {$$.start = $1.start; $$.end = push("=");}
       | LVALUEPROP '=' EXPRESSION    {$$.start = $1.start; $$.end = push("[=]");}
       | LVALUE INC_OP EXPRESSION     {$$.start = $1.start; push($1.str); push("@"); push("+"); $$.end = push("="); }
       | LVALUE DEC_OP EXPRESSION     {$$.start = $1.start; push($1.str); push("@"); push("-"); $$.end = push("="); }
       | LVALUEPROP INC_OP EXPRESSION {$$.start = $1.start; push($1.str); push("[@]"); push("+"); $$.end = push("[=]"); }
       | LVALUEPROP DEC_OP EXPRESSION {$$.start = $1.start; push($1.str); push("[@]"); push("-"); $$.end = push("[=]"); }
       ;

EXPRESSION : EXPRESSION '+' EXPRESSION        {$$.start = $1.start; $$.end = push("+");}
           | EXPRESSION '-' EXPRESSION        {$$.start = $1.start; $$.end = push("-");}
           | EXPRESSION '>' EXPRESSION        {$$.start = $1.start; $$.end = push(">");}
           | EXPRESSION '<' EXPRESSION        {$$.start = $1.start; $$.end = push("<");}
           | EXPRESSION '%' EXPRESSION        {$$.start = $1.start; $$.end = push("%");}
           | EXPRESSION '*' EXPRESSION        {$$.start = $1.start; $$.end = push("*");}
           | EXPRESSION '/' EXPRESSION        {$$.start = $1.start; $$.end = push("/");}
           | '-' {$$.start = push("0");} EXPRESSION                {$$.end = push("-");} 
           | EXPRESSION COMPARE_OP EXPRESSION {$$.start = $1.start; $$.end = push("==");}
           | NEW_ARRAY                        {$$.start = $$.end = push("[]"); }
           | NEW_OBJECT                       {$$.start = $$.end = push("{}"); }
           | ID	                              {$1.start = $1.end = push($1.str); $$.start = $1.start; $$.end = push("@"); }
           | NUM                              {$1.start = $1.end = push($1.str); $$=$1;}
           | STRING                           {$1.start = $1.end = push($1.str); $$=$1;}
           | LVALUEPROP                       {$$.start = $1.start; $$.end = push("[@]"); } 
           | ASSIGN
           | '(' EXPRESSION ')'               {$$ = $2;}
           ;

DECL_ASSIGN: ID {$1.start = push($1.str); push("&"); $1.end = push($1.str); $$.start = $1.start;}
             '=' EXPRESSION {push("="); $$.end = push("^");};

DECL_ELEMS: ID {$$.start = $1.start = push($1.str); $$.end =push("&");}',' DECL_ELEMS[tail] {$$.end = $tail.end;}
          | ID {$$.start = $1.start = $1.end = push($1.str); $$.end = push("&");}
          | DECL_ASSIGN ',' DECL_ELEMS[tail] {$$.start = $1.start;  $$.end = $tail.end;}
          | DECL_ASSIGN
          ;

DECL_LET: LET DECL_ELEMS {$$.start = $2.start; $$.end = $2.end;};

JUMP_FALSE: {push("!"); $$.start = push("-1"); $$.end = push("?"); }

FORCE_JUMP: {$$.start = push("-1"); $$.end = push("#");}

IF_STATEMENT: IF '(' EXPRESSION ')' JUMP_FALSE STATEMENT[block]
              {$$.start = $3.start; $$.end = $block.end;
               change_addr($3.start, $block.end + 1);}
            | IF '(' EXPRESSION ')' JUMP_FALSE[nq_jmp] STATEMENT[if_block] FORCE_JUMP[f_jmp] ELSE STATEMENT[else_block]
	      {change_addr($nq_jmp.start, $else_block.start); change_addr($f_jmp.start, $else_block.end + 1);
		$$.start = $3.start; $$.end = $else_block.end;}
	    ;

FOR_VARS: DECL_LET
        | ASSIGN {$$.start =$1.start; $$.end = push("^");}
        ;

FOR_STATEMENT: FOR '(' FOR_VARS[vars] ';' EXPRESSION[cond] JUMP_FALSE[break_loop] FORCE_JUMP[run] ';'  EXPRESSION
                { $$.start = $1.start; $$.end = push("^"); }
               FORCE_JUMP[test] ')' STATEMENT[block] FORCE_JUMP[loop]
                { $$.start = $vars.start; $$.end = $loop.end;
		 change_addr($break_loop.start, $loop.end + 1);
		 change_addr($loop.start, $run.end + 1);
		 change_addr($test.start, $cond.start);
		 change_addr($run.start, $block.start);
	        }

WHILE_STATEMENT: WHILE '(' EXPRESSION[test] JUMP_FALSE[break_loop] ')' STATEMENT FORCE_JUMP[loop]
                { $$.start = $3.start; $$.end = $loop.end;
		  change_addr($break_loop.start, $loop.end+1);
		  change_addr($loop.start, $test.start);
		}
%% 

#include "lex.yy.c"


void yyerror( const char* msg ) {
  cout << endl << "Erro: " << msg << endl
       << "Perto de : '" << yylval.str << "'" <<endl;
  exit( 0 );
}

void change_addr(int index, int addr) {
  stack[index] = to_string(addr);
}

int push( string st ) {
  stack.push_back(st);
  return stack.size() -1; 
}

void show(){
  for (string x : stack)
    cout << x << " ";
}

int main( int argc, char* argv[] ) {
  yyparse();
  push(".");
  show();
  return 0;
}

