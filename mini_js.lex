%{
#include <string>
int linha = 1; 
int coluna = 1;

int ultimo_token = -1;

%}

STRING1	\"(\"\"|\\\"|[^\"])*\"
STRING2	\'(\'\'|\\\'|[^\'])*\'

D    [0-9]
L    [A-Za-z_]
ID   {L}({L}|{D})*
NUM  {D}+("."{D}+)?


WS  [ \t\n\r]

%%

"\n"     { linha++; coluna =1;}

"let"    { linha+= 3; yylval.str = yytext; ultimo_token = LET; return LET;}
"var"    { linha+= 3; yylval.str = yytext; ultimo_token = VAR; return VAR;}
"const"  { linha+= 4; yylval.str = yytext; ultimo_token = CONST; return CONST;}

"if"    { linha+= 2; yylval.str = yytext; ultimo_token = IF; return IF;}
"else"  { linha+= 4; yylval.str = yytext; ultimo_token = ELSE; return ELSE;}
"for"   { linha+= 3; yylval.str = yytext; ultimo_token = FOR; return FOR;}
"while" { linha+= 5; yylval.str = yytext; ultimo_token = WHILE; return WHILE;}

"{}"   {linha +=2; yylval.str = yytext; ultimo_token = NEW_OBJECT; return NEW_OBJECT;}
"[]"   {linha +=2; yylval.str = yytext; ultimo_token = NEW_ARRAY ; return NEW_ARRAY;}

"+="   {linha +=2; yylval.str = yytext; ultimo_token = INC_OP; return INC_OP;}
"-="   {linha +=2; yylval.str = yytext; ultimo_token = DEC_OP; return DEC_OP;}
"=="   {linha +=2; yylval.str = yytext; ultimo_token = COMPARE_OP; return COMPARE_OP;}

{ID}   { coluna += strlen(yytext);
         yylval.str = yytext;
         ultimo_token = ID;
         return ID; }

{STRING1}|{STRING2}   { coluna += strlen(yytext);
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
