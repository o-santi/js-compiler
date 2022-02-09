%{
#include <iostream>
#include <string>
#include <map>
#include <vector>
  
using namespace std;

extern "C" int yylex();
extern "C" int ultimo_token, linha, coluna;

struct Atributos {
  string str;
  int start;
  int end;
};

#define YYSTYPE Atributos

enum TIPO_VARIAVEL {VAR_T, LET_T, CONST_T};
 
struct Variavel {
  TIPO_VARIAVEL tipo;
  int linha, coluna;
};
 
vector<string> stack;
vector<map<string, Variavel>> escopo; 

TIPO_VARIAVEL ultima_declaracao;
void push_escopo();
void pop_escopo();
void check_var(string nome);
void declare_var(string nome);
void change_addr(int index, int addr);
void erro( string msg );
int push( string st );
void copy(Atributos token);

// protótipo para o analisador léxico (gerado pelo lex)
int yylex();
void yyerror( const char* );
 
%}

%token	ID 
        NUM
        STRING
        BOOL
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
        INC_1
        DEC_OP
        DEC_1
        COMPARE_OP
        UNARY_MINUS

%start  STATEMENTS

%left '<' '>' '=' INC_OP DEC_OP COMPARE_OP
%left '+' '-'
%left '*' '/'
%left '%' '^'
%left UNARY_MINUS
%left INC_1 DEC_1


%nonassoc IF
%nonassoc ELSE

%%

STATEMENT : EXPRESSION ';' { $$.start = $1.start; $$.end = push("^");}
          | DECLARES ';'
	  | BLOCK
	  | IF_STATEMENT
	  | FOR_STATEMENT
	  | WHILE_STATEMENT
          ;

BLOCK : '{' {push_escopo();} STATEMENTS {pop_escopo();}'}' {$$ = $3;} ;
      

STATEMENTS : STATEMENT STATEMENTS {$$.start = $1.start; $$.end = $2.end;}
           | STATEMENT 
           ;

LVALUE : ID { $$.start = $$.end = $1.start = $1.end = push($1.str); $$.str = $1.str;};

LVALUEPROP: PROP;

PROP: EXPRESSION '[' EXPRESSION ']' {$$.start = $1.start; $$.end = $3.end;}
    | EXPRESSION '.' ID             {$$.start = $1.start; $$.end = $3.end = $3.start = push($3.str);}
    ; 

ASSIGN : LVALUE     '=' EXPRESSION {check_var($1.str); $$.start = $1.start; $$.end = push("=");}
       | LVALUEPROP '=' EXPRESSION {$$.start = $1.start; $$.end = push("[=]");}
       | LVALUE     INC_1          {check_var($1.str); $$.start = $1.start; push("@"); push($1.str); push($1.str); push("@"); push("1"); push("+"); push("="); $$.end = push("^"); }
       | LVALUE     DEC_1          {check_var($1.str); $$.start = $1.start; push("@"); push($1.str); push($1.str); push("@"); push("1"); push("-"); push("="); $$.end = push("^"); }
       | LVALUEPROP INC_1          {$$.start = $1.start; copy($1); push("[@]"); push("1"); push("+"); push("[=]"); $$.end = push("^");}
       | LVALUEPROP DEC_1          {$$.start = $1.start; copy($1); push("[@]"); push("1"); push("-"); push("[=]"); $$.end = push("^");}
       | LVALUE     {check_var($1.str);push($1.str); push("@"); }  INC_OP EXPRESSION {$$.start = $1.start; push("+"); $$.end = push("="); }
       | LVALUE     {check_var($1.str);push($1.str); push("@"); }  DEC_OP EXPRESSION {$$.start = $1.start; push("-"); $$.end = push("="); }
       | LVALUEPROP {copy($1); push("[@]"); } INC_OP EXPRESSION {$$.start = $1.start; push("+"); $$.end = push("[=]"); }
       | LVALUEPROP {copy($1); push("[@]"); } DEC_OP EXPRESSION {$$.start = $1.start; push("-"); $$.end = push("[=]"); } 
       ;

EXPRESSION : EXPRESSION '+' EXPRESSION        {$$.start = $1.start; $$.end = push("+");}
           | EXPRESSION '-' EXPRESSION        {$$.start = $1.start; $$.end = push("-");}
           | EXPRESSION '>' EXPRESSION        {$$.start = $1.start; $$.end = push(">");}
           | EXPRESSION '<' EXPRESSION        {$$.start = $1.start; $$.end = push("<");}
           | EXPRESSION '%' EXPRESSION        {$$.start = $1.start; $$.end = push("%");}
           | EXPRESSION '*' EXPRESSION        {$$.start = $1.start; $$.end = push("*");}
           | EXPRESSION '/' EXPRESSION        {$$.start = $1.start; $$.end = push("/");}
           | EXPRESSION COMPARE_OP EXPRESSION {$$.start = $1.start; $$.end = push("==");}
           | '-' {$$.start = push("0");} EXPRESSION {$$.end = push("-");} %prec UNARY_MINUS
           | ASSIGN 
           | F
           ;

F : ID	       {$1.start = $1.end = push($1.str); $$.start = $1.start; $$.end = push("@"); }
  | NUM        {$1.start = $1.end = push($1.str); $$=$1;}
  | STRING     {$1.start = $1.end = push($1.str); $$=$1;}
  | PROP       {$$.start = $1.start; $$.end = push("[@]"); }  
  | NEW_ARRAY                        {$$.start = $$.end = push("[]"); }
  | NEW_OBJECT                       {$$.start = $$.end = push("{}"); }
  | '(' EXPRESSION ')'               {$$ = $2;}
  ;

DECL_ASSIGN: ID {declare_var($1.str); $1.start = push($1.str); push("&"); $1.end = push($1.str); $$.start = $1.start;}
             '=' EXPRESSION {push("="); $$.end = push("^");};

DECL_ELEMS: ID {declare_var($1.str); $$.start = $1.start = push($1.str); $$.end = push("&");}
            ',' DECL_ELEMS[tail] {$$.end = $tail.end;}
          | ID {declare_var($1.str); $$.start = $1.start = $1.end = push($1.str); $$.end = push("&");}
          | DECL_ASSIGN ',' DECL_ELEMS[tail] {$$.start = $1.start;  $$.end = $tail.end;}
          | DECL_ASSIGN
          ;

DECL_ASSIGNS: DECL_ASSIGN ',' DECL_ELEMS[tail] {$$.start = $1.start; $$.end = $tail.end;}
            | DECL_ASSIGN 
            ;

DECLARES: LET   {ultima_declaracao = LET_T;}   DECL_ELEMS   {$$ = $3;}
        | VAR   {ultima_declaracao = VAR_T;}   DECL_ELEMS   {$$ = $3;}
        | CONST {ultima_declaracao = CONST_T;} DECL_ASSIGNS {$$ = $3;} 
        ; 

JUMP_FALSE: {push("!"); $$.start = push("-1"); $$.end = push("?"); }

FORCE_JUMP: {$$.start = push("-1"); $$.end = push("#");}

PAR: {ultimo_token = -1;}

IF_STATEMENT: IF '(' EXPRESSION ')' PAR JUMP_FALSE[jmp] STATEMENT[block]
              {$$.start = $3.start; $$.end = $block.end;
               change_addr($jmp.start, $block.end + 1);}
            | IF '(' EXPRESSION ')' PAR JUMP_FALSE[nq_jmp] STATEMENT[if_block] FORCE_JUMP[f_jmp] ELSE STATEMENT[else_block]
	      {change_addr($nq_jmp.start, $else_block.start);
	       change_addr($f_jmp.start,  $else_block.end + 1);
		$$.start = $3.start; $$.end = $else_block.end;}
	    ;

FOR_VARS: DECLARES
        | ASSIGN {$$.start =$1.start; $$.end = push("^");}
        ;

FOR_STATEMENT: FOR '(' FOR_VARS[vars] ';' EXPRESSION[cond] JUMP_FALSE[break_loop] FORCE_JUMP[run] ';'  EXPRESSION[inc]
                { $inc.end = push("^"); }
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

void check_var(string nome){
  for (auto m : escopo){
    if (m.count(nome) > 0)
      return;
  }
  cout << "." << endl;
  cerr << "Erro: a variável '" << nome << "' não foi declarada." << endl;
  exit(0);
}

void declare_var(string nome) {
  if (escopo.back().empty()){
    Variavel var = {ultima_declaracao, linha, coluna};
    escopo.back().insert({nome, var});
  }
  else if (escopo.back().count(nome) > 0){
    if (escopo.back().at(nome).tipo != VAR_T){
      cout << "." << endl;
      cerr << "Erro: a variável '" << nome <<"' já foi declarada na linha " << escopo.back().at(nome).linha << "." << endl;
      exit(0);
    }
    Variavel var = {ultima_declaracao, linha, coluna};
    escopo.back().at(nome) =  var;
  }
  else {
    Variavel var = {ultima_declaracao, linha, coluna};
    escopo.back().insert({nome, var});
  }
}

void push_escopo(){
  map<string, Variavel> m;
  escopo.push_back(m);
}

void pop_escopo(){
  escopo.pop_back();
}

void change_addr(int index, int addr) {
  if ( stack[index] != "-1" ){
    cout << "[ERRO] tentou trocar posicao de memoria invalida." << endl
         << "stack[" << index << "] = " << stack[index] << endl;
    exit(1);
  }
  stack[index] = to_string(addr);
}


int push( string st ) {
  stack.push_back(st);
  //cout << st << " ";
  return stack.size() -1; 
}

void copy(Atributos token){
  for (int i=token.start; i < token.end+1; i++)
    push(stack[i]);
}

void show(){
  for (string x : stack)
    cout << x << " ";
}

int main(void) {
  push_escopo();
  yyparse();
  push(".");
  pop_escopo();
  show();
  return 0;
}

