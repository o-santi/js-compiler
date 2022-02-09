#ifndef mdp_h
#define mdp_h

enum TOKEN { GOTO = '#', CALL_FUNC = '$', RET_FUNC = '~', GET = '@', SET = '=', JUMP_TRUE = '?', LET = '&', POP = '^',
 HALT = 256, ME_IG, MA_IG, DIF, IGUAL, E, OU, NEW_OBJECT, NEW_ARRAY, SET_PROP, GET_PROP, ID, CBOOL, CCHAR, CINT, CDOUBLE, CSTRING, OBJ_SET_PROP
};

extern void erro( std::string msg );
extern int yylex();
extern std::string lexema;

#endif
