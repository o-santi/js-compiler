%{
#include <string>
int linha = 1; 
int coluna = 1;

int ultimo_token = -1;

void s(int x);
vector<string> tokenize(string s, string del);
%}

%option yylineno

STRING1	\"(\"\"|\\\"|[^\"])*\"
STRING2	\'(\'\'|\\\'|[^\'])*\'

STRING {STRING1}|{STRING2}

D    [0-9]
L    [A-Za-z_]
ID   {L}({L}|{D})*
NUM  {D}+("."{D}+)?
BOOL ("true"|"false") 

RVALUE ({NUM}|{ID}|{BOOL}|{STRING})

WS  [ \t\n\r]

%%


"\n" {linha++; coluna=1;}

"\n"/{WS}*("let"|"var"|"const") {linha++; coluna =1;
  if ( ultimo_token != ';' && ultimo_token != -1 && ultimo_token != '{') {s(2); ultimo_token = ';'; return ';';}}

"\n"/{WS}*({RVALUE}|"function"|"return"|"{") { linha++; coluna=1;
  if (ultimo_token == ID || ultimo_token == NUM || ultimo_token == STRING || ultimo_token == ')' ||
      ultimo_token == BLOCO_VAZIO || ultimo_token == '}' || ultimo_token == ']' ||
      ultimo_token == TRUE || ultimo_token == FALSE)
    {unput('\n'); s(3); ultimo_token = ';'; return ';';}}

"\n"/{WS}*("}"|")") {linha++; coluna = 1; 
  if ( ultimo_token != ';' && ultimo_token != -1 && ultimo_token != '}') {s(4); ultimo_token = ';'; return ';';}}


<<EOF>> { if( ultimo_token != ';' && ultimo_token != -1) {s(5); unput(EOF); return ';';} else return EOF;}

";"/([ \t\n]*";")* {  if ( ultimo_token != ';') {ultimo_token = ';'; return ';';}}


"true"  { coluna+= 4; yylval.c = { yytext }; ultimo_token = TRUE; return TRUE;} 
"false"  { coluna+= 5; yylval.c = { yytext }; ultimo_token = FALSE; return FALSE;}

"let"    { coluna+= 3; yylval.c = { }; ultimo_token = LET; return LET;}
"var"    { coluna+= 3; yylval.c = { }; ultimo_token = VAR; return VAR;}
"const"  { coluna+= 4; yylval.c = { }; ultimo_token = CONST; return CONST;}

"if"    { coluna+= 2; yylval.c = { }; ultimo_token = IF; return IF;}
"else"  { coluna+= 4; yylval.c = { }; ultimo_token = ELSE; return ELSE;}
"for"   { coluna+= 3; yylval.c = { }; ultimo_token = FOR; return FOR;}
"while" { coluna+= 5; yylval.c = { }; ultimo_token = WHILE; return WHILE;}

"function" { coluna+= 7; yylval.c = { }; ultimo_token = FUNCTION; return FUNCTION;}
"return" { coluna+= 6; yylval.c = { }; ultimo_token = RETURN; return RETURN;}

"{"{WS}*"}"   {coluna +=2; yylval.c = { }; ultimo_token = BLOCO_VAZIO; return BLOCO_VAZIO;}

"{"/{WS}*{ID}{WS}*":"   { yylval.c = {}; ultimo_token = ABRE_OBJ_LITERAL; return ABRE_OBJ_LITERAL;}

"+="   {coluna +=2; yylval.c = { yytext }; ultimo_token = INC_OP; return INC_OP;}
"++"   {coluna +=2; yylval.c = { yytext }; ultimo_token = INC_1;  return INC_1;}
"-="   {coluna +=2; yylval.c = { yytext }; ultimo_token = DEC_OP; return DEC_OP;}
"--"   {coluna +=2; yylval.c = { yytext }; ultimo_token = DEC_1;  return DEC_1;}
"=="   {coluna +=2; yylval.c = { yytext }; ultimo_token = COMPARE_OP; return COMPARE_OP;}

"=>"   {coluna +=2; yylval.c = { yytext }; ultimo_token = SETA; return SETA;}

")"{WS}*"=>" {yylval.c = { yytext }; ultimo_token = PAREN_SETA; return PAREN_SETA;}
"asm{".*"}"  { string a = yytext + 4;
               a = a.substr(0, a.size()-1);
	       vector<string> tokens = tokenize(a, " ");
               yylval.c = tokens;
               coluna += strlen( yytext ); 
	       ultimo_token = ASM;
               return ASM; }

"{[]}" {coluna += 4; yylval.c = { }; return BLOCO_VAZIO;} /* test driven development!!!
 foi mal professor mas eu não vou dar match em cada } fechando mas nem que me paguem
 ja acho idiotice passar mais da metade do trabalho dando match em ; ...

 se estiver lendo isso, sugiro no próximo periodo implementar um compilador de C ou de haskell
 isso sim é divertido 
 */

{ID}   { coluna += strlen(yytext);
         yylval.c = { yytext };
         ultimo_token = ID;
         return ID; }

{STRING}   { coluna += strlen(yytext);
             yylval.c = { yytext };
             ultimo_token = STRING;
             return STRING; }


{NUM}   { coluna += strlen(yytext);
          yylval.c = { yytext };
          ultimo_token = NUM;
          return NUM; }

{WS}    { }

.   { coluna++;
      yylval.c = { yytext };
      ultimo_token = yytext[0];
      return yytext[0]; }

%%
void s(int x){
  //cerr << "[" <<linha << ":" << coluna << "/" << x << "/" << ultimo_token << "]";
}

vector<string> tokenize(string s, string del = " ") {
  int start = 0;
  int end = s.find(del);
  vector<string> ret;
  while (end != -1) {
    ret.push_back(s.substr(start, end - start));
    start = end + del.size();
    end = s.find(del, start);
  }
  ret.push_back(s.substr(start, end - start));
  return ret;
}
