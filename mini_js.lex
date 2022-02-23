%{
#include <string>
int linha = 1; 
int coluna = 1;

int ultimo_token = -1;

void s();
vector<string> tokenize(string s, string del);
%}

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


"\n"     { linha++; coluna=1;}

"\n"$    { linha++; coluna=1; if(ultimo_token != ';' && ultimo_token != -1) {s(); ultimo_token = ';'; return ';';}}

"\n"/{WS}*("let"|"var"|"const") {linha++; coluna =1;
  if ( ultimo_token != ';' && ultimo_token != -1 && ultimo_token != '{') {s(); ultimo_token = ';'; return ';';}}

"\n"/{WS}*({RVALUE}|"print"|"println"|"function"|"return") {linha++; coluna=1; 
  if (ultimo_token == ID || ultimo_token == NUM || ultimo_token == STRING || ultimo_token == ')' ||
      ultimo_token == NEW_ARRAY || ultimo_token == NEW_OBJECT || ultimo_token == '}')
    {s(); ultimo_token = ';'; return ';';}}

"\n"/{WS}*("}"|")") {linha++; coluna =1;
  if ( ultimo_token != ';' && ultimo_token != -1 ) {s(); ultimo_token = ';'; return ';';}}

<<EOF>> { if( ultimo_token != ';' && ultimo_token != -1) {s(); unput(EOF); return ';';} else return EOF;}


"true"  { coluna+= 4; yylval.c = { yytext }; ultimo_token = TRUE; return TRUE;} 
"false"  { coluna+= 5; yylval.c = { yytext }; ultimo_token = FALSE; return FALSE;}

"let"    { coluna+= 3; yylval.c = { yytext }; ultimo_token = LET; return LET;}
"var"    { coluna+= 3; yylval.c = { yytext }; ultimo_token = VAR; return VAR;}
"const"  { coluna+= 4; yylval.c = { yytext }; ultimo_token = CONST; return CONST;}

"if"    { coluna+= 2; yylval.c = { yytext }; ultimo_token = IF; return IF;}
"else"  { coluna+= 4; yylval.c = { yytext }; ultimo_token = ELSE; return ELSE;}
"for"   { coluna+= 3; yylval.c = { yytext }; ultimo_token = FOR; return FOR;}
"while" { coluna+= 5; yylval.c = { yytext }; ultimo_token = WHILE; return WHILE;}
"do"    { coluna+= 2; yylval.c = { yytext }; ultimo_token = DO; return DO;}

"print"    { coluna+= 5; yylval.c = { yytext }; ultimo_token = PRINT; return PRINT;}
"println"    { coluna+= 7; yylval.c = { yytext }; ultimo_token = PRINTLN; return PRINTLN;}
"function" { coluna+= 7; yylval.c = { yytext }; ultimo_token = FUNCTION; return FUNCTION;}
"return" { coluna+= 6; yylval.c = { yytext }; ultimo_token = RETURN; return RETURN;}

"{}"   {coluna +=2; yylval.c = { yytext }; ultimo_token = NEW_OBJECT; return NEW_OBJECT;}
"[]"   {coluna +=2; yylval.c = { yytext }; ultimo_token = NEW_ARRAY ; return NEW_ARRAY;}

"+="   {coluna +=2; yylval.c = { yytext }; ultimo_token = INC_OP; return INC_OP;}
"++"   {coluna +=2; yylval.c = { yytext }; ultimo_token = INC_1;  return INC_1;}
"-="   {coluna +=2; yylval.c = { yytext }; ultimo_token = DEC_OP; return DEC_OP;}
"--"   {coluna +=2; yylval.c = { yytext }; ultimo_token = DEC_1;  return DEC_1;}
"=="   {coluna +=2; yylval.c = { yytext }; ultimo_token = COMPARE_OP; return COMPARE_OP;}

"=>"   {coluna +=2; yylval.c = { yytext }; ultimo_token = SETA; return SETA;}

"asm{".*"}"  { string a = yytext + 4;
               a = a.substr(0, a.size()-1);
               yylval.c = tokenize(a, " ");
               coluna += strlen( yytext ); 
	       ultimo_token = ASM;
               return ASM; }

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
void s(){
  //cout << "[" <<linha << ":" << coluna << "]";
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
