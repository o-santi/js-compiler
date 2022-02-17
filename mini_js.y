%{
#include <iostream>
#include <string>
#include <map>
#include <vector>
  
using namespace std;

extern "C" int yylex();
extern "C" int ultimo_token, linha, coluna;

struct Atributos {
  vector<string> c;
};

#define YYSTYPE Atributos

enum TIPO_VARIAVEL {VAR_T, LET_T, CONST_T};
 
struct Variavel {
  TIPO_VARIAVEL tipo;
  int linha;
  int coluna;
};

struct Funcao {
  int linha;
  int coluna;
  int addr;
  vector<string> params;
};

vector<string> stack;
vector<map<string, Variavel>> escopo;
TIPO_VARIAVEL ultima_declaracao;
int arg_count = 0;
int param_count = 0;
vector<string> funcoes;
bool function_declaration = false;
bool before = false;

void push_escopo();
void pop_escopo();
void check_var(string nome);
vector<string> declare_var(string nome);
Variavel find_var(string nome);
 
string new_label();
string here(string label);
void show(vector<string> code);
vector<string> resolver_enderecos(vector<string> code);

// protótipo para o analisador léxico (gerado pelo lex)
int yylex();
void yyerror( const char* );

// overloads
vector<string> concatena( vector<string> a, vector<string> b ); 
vector<string> operator+( vector<string> a, vector<string> b ); 
vector<string> operator+( vector<string> a, string b ) ;
vector<string> operator+( string a, vector<string> b );
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
        DO
        INC_OP
        INC_1
        DEC_OP
        DEC_1
        COMPARE_OP
        UNARY_MINUS
        RETURN
        FUNCTION
        PRINT
        PRINTLN

%start START
%right '='
%left  '<' '>' INC_OP DEC_OP COMPARE_OP
%left  '+' '-'
%left  '*' '/'
%left  '%' '^'
%left  UNARY_MINUS
%left  '[' '.' '('
%left  INC_1 DEC_1


%%

START: STATEMENTS { show(resolver_enderecos($1.c + "." + funcoes));}

STATEMENT : EXPRESSION ';' { $$.c = $1.c + "^";}
          | DECLARES ';'
	  | BLOCK
	  | PRINT_STATEMENT ';'
	  | IF_STATEMENT
	  | FOR_STATEMENT
	  | WHILE_STATEMENT
	  | FUNCTION_STATEMENT
	  | RETURN_STATEMENT ';'
          ;

BLOCK : '{' PAR {push_escopo();} STATEMENTS '}' {pop_escopo(); $$.c = "<{" + $4.c + "}>"; };
      

STATEMENTS : STATEMENT STATEMENTS {$$.c = $1.c + $2.c;}
           | STATEMENT 
           ;

PROP: EXPRESSION '[' EXPRESSION ']' {$$.c = $1.c + $3.c; }
    | EXPRESSION '.' ID             {$$.c = $1.c + $3.c; }
    ;  

ASSIGN : ID   '=' EXPRESSION    {$$.c = $1.c + $3.c + "="; check_var($1.c[0]); }
       | PROP '=' EXPRESSION    {$$.c = $1.c + $3.c + "[=]";}
       | ID   INC_1             {$$.c = $1.c + "@" + $1.c + $1.c +  "@" + "1" + "+" + "=" + "^"; check_var($1.c[0]); }
       | ID   DEC_1             {$$.c = $1.c + "@" + $1.c + $1.c +  "@" + "1" + "-" + "=" + "^"; check_var($1.c[0]); }
       | PROP INC_1             {$$.c = $1.c + "[@]" + $1.c + $1.c + "[@]" + "1" + "+" + "=" + "^";}
       | PROP DEC_1             {$$.c = $1.c + "[@]" + $1.c + $1.c + "[@]" + "1" + "-" + "=" + "^";}
       | ID   INC_OP EXPRESSION {$$.c = $1.c + $1.c + "@"   + $3.c + "+" + "=" ; check_var($1.c[0]); }
       | ID   DEC_OP EXPRESSION {$$.c = $1.c + $1.c + "@"   + $3.c + "-" + "=" ; check_var($1.c[0]);}
       | PROP INC_OP EXPRESSION {$$.c = $1.c + $1.c + "[@]" + $3.c + "+" + "[=]" ;}
       | PROP DEC_OP EXPRESSION {$$.c = $1.c + $1.c + "[@]" + $3.c + "-" + "[=]" ;} 
       ;

EXPRESSION : EXPRESSION '+' EXPRESSION        {$$.c = $1.c + $3.c + "+";}
           | EXPRESSION '-' EXPRESSION        {$$.c = $1.c + $3.c + "-";}
           | EXPRESSION '>' EXPRESSION        {$$.c = $1.c + $3.c + ">";}
           | EXPRESSION '<' EXPRESSION        {$$.c = $1.c + $3.c + "<";}
           | EXPRESSION '%' EXPRESSION        {$$.c = $1.c + $3.c + "%";}
           | EXPRESSION '*' EXPRESSION        {$$.c = $1.c + $3.c + "*";}
           | EXPRESSION '^' EXPRESSION        {$$.c = $1.c + $3.c + "^";}
           | EXPRESSION '/' EXPRESSION        {$$.c = $1.c + $3.c + "/";}
           | EXPRESSION COMPARE_OP EXPRESSION {$$.c = $1.c + $3.c + "==";}
           | '-' EXPRESSION                   {$$.c = "0"  + $2.c + "-";} %prec UNARY_MINUS
           | ASSIGN
           | F
           ;

F : ID	         {$$.c = $1.c + "@";}
  | NUM                
  | STRING             
  | PROP         {$$.c = $1.c + "[@]";}  
  | NEW_ARRAY          
  | NEW_OBJECT         
  | '(' EXPRESSION ')' {$$ = $2;}
  | FUNCTION_CALL
  ;

DECL_ASSIGN: ID '=' EXPRESSION {$$.c = declare_var($1.c[0]) + $1.c + $3.c + "=" + "^"; };

DECL_ELEMS: ID ',' DECL_ELEMS[tail]          {$$.c = declare_var($1.c[0]) + $tail.c;}
          | ID                               {$$.c = declare_var($1.c[0]);} 
          | DECL_ASSIGN ',' DECL_ELEMS[tail] {$$.c = $1.c + $tail.c;}
          | DECL_ASSIGN
          ;

DECL_ASSIGNS: DECL_ASSIGN ',' DECL_ELEMS[tail] {$$.c = $1.c + $tail.c;}
            | DECL_ASSIGN
            ;

DECLARES: LET   {ultima_declaracao = LET_T;}   DECL_ELEMS   {$$ = $3;}
        | VAR   {ultima_declaracao = VAR_T;}   DECL_ELEMS   {$$ = $3;}
        | CONST {ultima_declaracao = CONST_T;} DECL_ASSIGNS {$$ = $3;} 
        ;

PAR: {ultimo_token = -1;}

PRINT_STATEMENT: PRINT   '(' EXPRESSION ')' {$$.c = $3.c + $1.c + "#";}
               | PRINTLN '(' EXPRESSION ')' {$$.c = $3.c + $1.c + "#";}

IF_STATEMENT: IF '(' EXPRESSION ')' PAR STATEMENT[block]
              { string test = new_label();
		$$.c = $3.c + "!" + test + "?" + $block.c + here(test);}
            | IF '(' EXPRESSION ')' PAR STATEMENT[if_block] ELSE STATEMENT[else_block]
	      { string test = new_label();
		string end = new_label();
	        $$.c = $3.c + "!" + test + "?" + $if_block.c + end + "#" + here(test) + $else_block.c + here(end);} 
	    ;

FOR_VARS: DECLARES
        | ASSIGN {$$.c = $1.c + "^";}
        ;

FOR_STATEMENT: FOR '(' FOR_VARS[decl] ';' EXPRESSION[cond] ';' EXPRESSION[update]  ')' STATEMENT[block]
             {
	       string test = new_label();
	       string loop = new_label();
	       string run  = new_label();
	       $$.c = $decl.c + here(test) + $cond.c + run + "?" + loop + "#" + here(run) +  $block.c +  $update.c + "^" + test + "#" + here(loop);
	     }

WHILE_STATEMENT: WHILE '(' EXPRESSION[cond] ')' STATEMENT[block]
                {
		  string test = new_label();
		  string end  = new_label();
		  $$.c = here(test) + $cond.c + "!" + end + "?" + $block.c + test + "#" + here(end);
		}

FUNCTION_PARAMS: FUNCTION_PARAMS[tail] ',' ID {$$.c = $3.c + "&" + $3.c + "arguments" + "@" + to_string(param_count++) + "[@]" + "=" + "^" + $tail.c;}
               | ID                           {$$.c = $1.c + "&" + $1.c + "arguments" + "@" + to_string(param_count++) + "[@]" + "=" + "^";} 
               |                              {$$.c = {};}

FUNCTION_STATEMENT: FUNCTION ID[name] '(' FUNCTION_PARAMS[params] ')' PAR
                     '{' {before = function_declaration; function_declaration = true;push_escopo(); }
                    STATEMENTS[block] '}'
                   {
		     string start = new_label();
		     vector<string> bloco = {};
  		     bloco = {here(start)};
		     bloco = bloco + $params.c + "undefined" + $block.c + "'&retorno'" + "@" + "~";
		     funcoes = funcoes + bloco;
		     function_declaration = before;
		     pop_escopo();
		     $$.c  = declare_var($name.c[0]) + $name.c + "{}" + "=" + "^" + $name.c + "@" + "'&funcao'" + start + "[=]" + "^";
		     param_count = 0;
		   }

ARGS: EXPRESSION ',' ARGS {$$.c = $1.c + $3.c; arg_count++;}
    | EXPRESSION          {$$ = $1; arg_count ++;}
    |                     {$$.c = {};}


FUNCTION_CALL: EXPRESSION '(' {arg_count = 0;} ARGS ')'
               {
		 $$.c = $4.c + to_string(arg_count) + $1.c + "$";
		 arg_count = 0;
	       }

RETURN_STATEMENT: RETURN EXPRESSION
                 {
		   if (!function_declaration){
		     cerr << "Erro: return fora de declaração de função na linha " << linha << endl;
		     cout << ".";
		     exit( 0 );
		   }
		   $$.c = {"^"};
		   $$.c = $$.c + $2.c;
		 }

%% 

#include "lex.yy.c"

void yyerror( const char* msg ) {
  cout << "." << endl;
  cerr << endl << "Erro: " << msg << endl
       << "Perto de : '" << yylval.c[0] << "'" <<  "("
       << linha << ":" << coluna << ")" <<endl;
  exit( 0 );
}  

string here(string label){
  return ":" + label;
}


vector<string> concatena( vector<string> a, vector<string> b ) {
  a.insert( a.end(), b.begin(), b.end() );
  return a;
}

vector<string> operator+( vector<string> a, vector<string> b ) {
  return concatena( a, b );
}

vector<string> operator+( vector<string> a, string b ) {
  a.push_back( b );
  return a;
}

vector<string> operator+( string a, vector<string> b ) {
  b.insert(b.begin(), a);
  return b;
}

Variavel find_var(string nome){
  for (auto i = escopo.rbegin(); i != escopo.rend(); ++i){
    auto m = *i;
    if (m.count(nome)){
      return m.at(nome);
    }
  }
  cout << "." << endl;
  cerr << "Erro: a variável '" << nome << "' não foi declarada." << endl;
  exit(0);
}

void check_var(string nome){
  // no need to check for variable declarations inside functions
  if (function_declaration)
    return;
  auto var = find_var(nome);
  if (var.tipo == CONST_T){
    cout << "." << endl;
    cerr << "Erro: tentativa de modificar uma variável constante ('" << nome << "')." << endl;
    exit( 0 );
  }
} 


vector<string> declare_var(string nome) {
  vector<string> str = {};
  if (escopo.back().count(nome)){
    if (escopo.back().at(nome).tipo != VAR_T){
      cout << "." << endl;
      cerr << "Erro: a variável '" << nome <<"' já foi declarada na linha " << escopo.back().at(nome).linha << "." << endl;
      exit(0);
    }
    Variavel var = {ultima_declaracao, linha, coluna};
    escopo.back().at(nome) = var;
    return str;
  }
  else {
    for (auto i = escopo.rbegin(); i != escopo.rend(); ++i){
      auto m = *i;
      if (m.count(nome)){
	Variavel var = {ultima_declaracao, linha, coluna};
	escopo.back().insert({nome, var});
	str = str + nome + "&";
	return str;
      }
    }
    Variavel var = {ultima_declaracao, linha, coluna};
    escopo.back().insert({nome, var});
    str = str + nome + "&";
    return str;
  }
}

void push_escopo(){
  map<string, Variavel> m;
  escopo.push_back(m);
}

void pop_escopo(){
  escopo.pop_back();
}

void show(vector<string> code){
  for (auto x: code)
    cout << x << " ";
}

string new_label( ) {
  static int n = 0;
  return "$label_" + to_string( ++n );
}

vector<string> resolver_enderecos( vector<string> entrada ) {
  map<string,int> label;
  vector<string> saida;
  for(  int i = 0; i < (signed int) entrada.size(); i++ ) 
    if( entrada[i][0] == ':' ) 
        label[entrada[i].substr(1)] = saida.size();
    else
      saida.push_back( entrada[i] );
  
  for( int i = 0; i < (signed int) saida.size(); i++ )
    if( label.count( saida[i] ) )
        saida[i] = to_string(label[saida[i]]);
  return saida;
}

int main(void) {
  map<string, Variavel> global;
  escopo.push_back(global);
  yyparse();
  return 0;
}

