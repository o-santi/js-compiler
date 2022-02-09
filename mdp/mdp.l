%{ 
#include <stdlib.h>
#include <map>
#include <vector>
#include <string>
#include <iostream>

#include "mdp.h"

using namespace std;

int linha = 1;
int coluna = 1;
std::string lexema = "";

int token( int );

%}

D  	[0-9]
L   	[A-Za-z_]
INT	{D}+
DOUBLE  {D}+"."{D}+([Ee][+\-]?{D}+)?
ID      {L}({L}|{D})*
CHAR 	"'"[^'\\]|(\\"n"|\\"t"|\\\\)"'"
STRING 	(\"([^\"\n]|(\\\")|\"\")+\")|(\'([^\'\n]|(\\\')|\'\')+\')
BOOL	"true"|"false"
    
%%

"\t"       { coluna += 4; }
" "        { coluna++; }
"\n"	   { linha++; coluna = 1; }

{DOUBLE}   { return token( CDOUBLE ); }
{STRING}   { return token( CSTRING ); }
{INT}	   { return token( CINT ); } 
{CHAR}	   { return token( CCHAR ); }

"&&"	   { return token( E ); }
"||"	   { return token( OU ); }
"<="	   { return token( ME_IG ); }
">="	   { return token( MA_IG ); }
"!="	   { return token( DIF ); }
"=="	   { return token( IGUAL ); }

"{}"	   { return token( NEW_OBJECT ); } 
"[]"	   { return token( NEW_ARRAY ); } 

"[@]"      { return token( GET_PROP ); }
"[=]"      { return token( SET_PROP ); }
"[<=]"     { return token( OBJ_SET_PROP ); }
"."        { return token( HALT ); }
{BOOL}     { return token( CBOOL ); }

{ID}       { return token( ID ); }

.          { return token( *yytext ); }

%%

int token( int tk ) {  
  lexema = yytext; 
  coluna += strlen( yytext ); 

  return tk;
}

auto nada = yyunput;
