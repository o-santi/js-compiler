%{
#include <string>
int linha = 1; 
int coluna = 1;

int ultimo_token = -1;

void s();
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

"\n"$    { linha++; coluna=1; if(ultimo_token != ';' && ultimo_token != '}') {s(); ultimo_token = ';'; return ';';}}

"\n"/{WS}*("let"|"var"|"const") {linha++; coluna =1;
  if ( ultimo_token != ';' && ultimo_token != -1) {s(); ultimo_token = ';'; return ';';}}

"\n"/{WS}*{RVALUE} {linha++; coluna=1; s();
  if (ultimo_token == ID || ultimo_token == NUM || ultimo_token == STRING || ultimo_token == ')' ||
      ultimo_token == NEW_ARRAY || ultimo_token == NEW_OBJECT )
    {ultimo_token = ';'; return ';';}}

"\n"/{WS}*("}"|")") {linha++; coluna =1;
  if ( ultimo_token != ';' && ultimo_token != -1 && ultimo_token != '}') {ultimo_token = ';'; return ';';}}

"let"    { coluna+= 3; yylval.str = yytext; ultimo_token = LET; return LET;}
"var"    { coluna+= 3; yylval.str = yytext; ultimo_token = VAR; return VAR;}
"const"  { coluna+= 4; yylval.str = yytext; ultimo_token = CONST; return CONST;}

"if"    { coluna+= 2; yylval.str = yytext; ultimo_token = IF; return IF;}
"else"  { coluna+= 4; yylval.str = yytext; ultimo_token = ELSE; return ELSE;}
"for"   { coluna+= 3; yylval.str = yytext; ultimo_token = FOR; return FOR;}
"while" { coluna+= 5; yylval.str = yytext; ultimo_token = WHILE; return WHILE;}

"{}"   {coluna +=2; yylval.str = yytext; ultimo_token = NEW_OBJECT; return NEW_OBJECT;}
"[]"   {coluna +=2; yylval.str = yytext; ultimo_token = NEW_ARRAY ; return NEW_ARRAY;}

"+="   {coluna +=2; yylval.str = yytext; ultimo_token = INC_OP; return INC_OP;}
"++"   {coluna +=2; yylval.str = yytext; ultimo_token = INC_1;  return INC_1;}
"-="   {coluna +=2; yylval.str = yytext; ultimo_token = DEC_OP; return DEC_OP;}
"--"   {coluna +=2; yylval.str = yytext; ultimo_token = DEC_1;  return DEC_1;}
"=="   {coluna +=2; yylval.str = yytext; ultimo_token = COMPARE_OP; return COMPARE_OP;}

{ID}   { coluna += strlen(yytext);
         yylval.str = yytext;
         ultimo_token = ID;
         return ID; }

{STRING}   { coluna += strlen(yytext);
             yylval.str = yytext;
             ultimo_token = STRING;
             return STRING; }


{NUM}   { coluna += strlen(yytext);
          yylval.str = yytext;
          ultimo_token = NUM;
          return NUM; }

{WS}    { }

.   { coluna++;
      yylval.str = yytext;
      ultimo_token = yytext[0];
      return yytext[0]; }

%%
void s(){
  //cout << ultimo_token <<  " ; ";
}
