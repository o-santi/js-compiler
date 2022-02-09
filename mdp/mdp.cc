#include <stdlib.h>
#include <map>
#include <vector>
#include <string>
#include <iostream>

#include "mdp.h"
#include "var_object.cc"

using namespace std;

extern bool online_judge;

// Pilha de execução de operações - corresponde aos registradores em uma máquina convencional
vector<Var> pilha;

// Representa os registros de ativacao. O primeiro deles é o ambiente global.
vector<Var> pilha_ra; 

map<int,string> nome_instrucao = {
  { GOTO, "# (goto)" },  
  { CALL_FUNC, "$ (callFunc)" },  
  { RET_FUNC, "~ (retFunc)" },  
  { GET, "@ (get)" },  
  { SET, "= (set)" },  
  { POP, "^ (pop)" },  
  { JUMP_TRUE, "? (jumpTrue)" },  
  { LET, "& (let)" },  
  { GET_PROP, "[@] (getProp)" },  
  { SET_PROP, "[=] (setProp)" },  
  { OBJ_SET_PROP, "[<=] (objSetProp)" },  
  { HALT, ". (halt)" },
  { NEW_ARRAY, "[] (newArray)" },  
  { NEW_OBJECT, "{} (newObject)" },  
  { IGUAL, "==" },  
  { DIF, "!=" },  
  { MA_IG, ">=" },  
  { ME_IG, "<=" },
  { OU, "||" },
  { E, "&&" }  
};

vector<Codigo> tokeniza() {
  vector<Codigo> codigo;
  int token = 0;
  
  while( (token = yylex()) != 0 ) 
    switch( token ) {
      case ID: codigo.push_back( Var( lexema ) );  break;
      case CBOOL: codigo.push_back( Var( lexema == "true" ) );  break;
      case CCHAR: codigo.push_back( Var( lexema[0] ) );  break;
      case CINT: codigo.push_back( Var( stoi( lexema ) ) );  break;
      case CDOUBLE: codigo.push_back( Var( stod( lexema ) ) );  break;
      case CSTRING: codigo.push_back( Var( lexema.substr( 1, lexema.length() - 2 ) ) );  break;

      default: 
	codigo.push_back( token );  
    }

  return codigo;
}

inline void push( Var valor ) {
  pilha.push_back( valor );
}

inline Var pop() {
  if( pilha.size() <= 0 )
    erro( "Tentou desempilhar mas a pilha está vazia" );
  
  Var temp = pilha.back();
  pilha.pop_back();
  
  return temp;
}

inline pair<Var,Var> pop2() {
  auto second = pop();
  auto first = pop();
  
  return pair{ first, second };
}

ostream& operator << ( ostream& o, const map<string,Var>& v ) {
  for( auto x : v ) 
    cout << "|" << x.first << " ==> " << x.second << "|" << endl;
  
  return o;
}

ostream& operator << ( ostream& o, const vector<Var>& v ) {
  for( unsigned int i = 0; i < 10 && i < v.size(); i++ ) 
    cout << "|" << v[i] << "|" << endl;
  
  return o;
}

ostream& operator << ( ostream& o, const Codigo& c ) {
  if( c.index() == 0 ) {
    if( auto itr = nome_instrucao.find(get<0>(c)); itr != nome_instrucao.end() ) 
      o << itr->second;
    else
      o << (char) get<0>(c);
  }
  else
    o << get<1>(c);
  
  return o;
}

ostream& operator << ( ostream& o, const vector<Codigo>& v ) {
  for( unsigned int i = 0; i < v.size(); i++ ) 
    o << i << ": " << v[i] << endl;
  
  return o;
}

typedef void (*Funcao)();

map<string, Funcao> func = {
  { "has_property", []() { auto p = pop2(); push( p.second.hasProperty( p.first.toString() ) ); } },
  { "to_string", []() { push( pop().toString() ); } },
  { "print", []() { cout << pop(); } },
  { "println", []() { cout << pop() << endl; } }
};

const Var undefined;

inline void create_global_context() {
  pilha_ra.push_back( newObject() );
  pilha_ra[0] = newObject(); 
  pilha_ra[0].setProp( "undefined" ) = Var();
}

inline Var& topo_ra() {
  return pilha_ra.at( pilha_ra.size()-1 );
}

int oldPC = 0;

void erro( string msg ) {
  cerr << "=== Erro: " << msg << " ===" <<endl;
  cerr << "=== PC: " << oldPC << " ===" << endl;
  cerr << "=== Vars ===" << endl << pilha_ra;
  cerr << "=== Pilha ===" << endl << pilha;
  exit( 1 ); 
}

int main( int argc, char*argv[] ) try {
  vector<Codigo> codigo = tokeniza();
  int PC = 0;
  bool fim = false, debug = (argc > 1 && argv[1] == string("debug"));
  pair<Var,Var> p;
  Var topo;
 
  cout << codigo << endl;
  cout << "=== Console ===" << endl;

  create_global_context();
  
  while( !fim ) {
    if( debug ) {
      cout << "=== PC: " << PC << " ===" << endl;
      cout << "=== Vars ===" << endl << pilha_ra;
      cout << "=== Pilha ===" << endl << pilha;
    }
    
    oldPC = PC;
    Codigo instrucao = codigo.at( PC++ );
    
    if( instrucao.index() == 0 )
      try {
	switch( get<0>( instrucao ) ) {
	  
	  case NEW_OBJECT: push( newObject() ); break;
	  case NEW_ARRAY: push( newArray() ); break;
	  case GET_PROP: p = pop2(); push( p.first[p.second] ); break;
	  case SET_PROP: topo = pop(); p = pop2(); p.first.setProp( p.second ) = topo; push( topo ); break;
	  case OBJ_SET_PROP: topo = pop(); p = pop2(); p.first.setProp( p.second ) = topo; push( p.first ); break;

	  case GOTO: 
	    topo = pop(); 
	    if( topo.isNumber() ) 
	      PC = topo.asInt(); 
	    else
	      if( func.find( topo.asString() ) != func.end() )
		func[topo.asString()]();
	      else
		erro( "Função interna não definida: " + topo.asString() );	    
	    break;
	  
	  case POP: pop(); break;
	  
	  case LET: {
	    Var& topo = topo_ra();
	    const string& nome = pop().asString();
  
	    if( topo.hasProperty( nome ) ) 
	        erro( "Variável já definida nesse escopo: " + nome ); 
	    
	    topo.setProp( nome ) = undefined;
	    
	    break;	    
	  }
	  
	  case GET: {
	    const string& nome = pop().asString();
	    bool encontrou = false;
	    
	    for( int i = pilha_ra.size() - 1; !encontrou && i >= 0; i-- )
	       if( pilha_ra[i].hasProperty( nome ) ) {
		 push( pilha_ra[i][nome] );
		 encontrou = true;
	       }
	    
	    if( !encontrou ) 
	      erro( "Variável não declarada: " + nome );
	    
	    break;
	  }
	  
	  case SET: {
	    p = pop2(); 
	    const string& nome = p.first.asString();
	    bool encontrou = false;
	    
	    for( int i = pilha_ra.size() - 1; !encontrou && i >= 0; i-- )
	       if( pilha_ra[i].hasProperty( nome ) ) {
		 pilha_ra[i].setProp( nome ) = p.second;
		 encontrou = true;
	       }
	    
	    if( !encontrou ) 
	      erro( "Variável não declarada: " + nome );
	    
	    push( p.second );
	    break;
	  }
	  
	  case CALL_FUNC: {
	    Var ra = newObject();
	    Var args = newArray();

	    p = pop2();	    
	    ra.setProp( "&retorno" ) = PC;
	    ra.setProp( "arguments" ) = args;
	    
	    for( int i = p.first.asInt() - 1; i >= 0; i-- )
	      args.setProp( i ) = pop(); 
	      
	    pilha_ra.push_back( ra );
	    PC = p.second["&funcao"].asInt(); // Falta a captura (closure) 
	    break;
	  }
	  
	  case RET_FUNC: {
	    int endereco = pop().asInt(); 
	    PC = endereco;
	    pilha_ra.pop_back();
	    break;
	  }
	  
	  case JUMP_TRUE: p = pop2(); if( p.first.asBool() ) PC = p.second.asInt(); break;
	  
	  case E    : p = pop2(); push( p.first && p.second ); break;
	  case OU   : p = pop2(); push( p.first || p.second ); break;
	  case ME_IG: p = pop2(); push( p.first <= p.second ); break;
	  case MA_IG: p = pop2(); push( p.first >= p.second ); break;
	  case DIF  : p = pop2(); push( p.first != p.second ); break; 
	  case IGUAL: p = pop2(); push( p.first == p.second ); break;
	  case '+'  : p = pop2(); push( p.first + p.second ); break;
	  case '-'  : p = pop2(); push( p.first - p.second ); break;
	  case '*'  : p = pop2(); push( p.first * p.second ); break;
	  case '/'  : p = pop2(); push( p.first / p.second ); break;
	  case '%'  : p = pop2(); push( p.first % p.second ); break;
	  case '<'  : p = pop2(); push( p.first < p.second ); break;
	  case '>'  : p = pop2(); push( p.first > p.second ); break;
	  case '!'  : push( !pop() ); break;

	  case HALT: fim = true; break;
	    
	  default:
	    erro( string( "Instrução inválida: " ) + (char) get<0>( instrucao ) );
        }
      }
      catch( const bad_variant_access& e ) {
	erro( string( "Parâmetro para instrução com tipo inválido: " ) + e.what() );
      }
    else {
      push( get<1>( instrucao ) );
    }      
  }
  
  online_judge = true;
  cout << "=== Vars ===" << endl << pilha_ra;
  cout << "=== Pilha ===" << endl << pilha;
  
  return 0;
}
catch( Var::Erro e ) {
  erro( e() );
}
