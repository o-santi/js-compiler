#include <stdlib.h>
#include <map>
#include <vector>
#include <string>
#include <iostream>

#include "mdp.h"
#include "var_object.cc"

using namespace std;

extern bool online_judge;

class Pilha {
  public:
    void push( const Var& valor  ) {
      if( v.size() >= 100 )
        erro( "Stack overflow: possivelmente seu programa está em loop" );

      v.push_back( valor );
    }
    
    Var pop() {
      if( v.size() <= 0 )
        erro( "Tentou desempilhar mas a pilha está vazia" );
      
      Var valor = v.back();
      v.pop_back();

      return valor;
    }

    Var& top() {
      return v.back();
    }

    pair<Var,Var> pop2() {
      Var second = pop();
      Var first = pop();
     
      return pair{ first, second };
    }

    ostream& print( ostream& o ) const {
      for( unsigned int i = 0; i < 100 && i < v.size(); i++ ) 
        cout << "|" << v[i] << "|" << endl;

      return o;
    }


  protected:
    vector<Var> v;
};

class PilhaRA : public Pilha {
  public:

    auto size() const {
      return v.size();
    }

    // Tenta declarar uma variável no escopo atual.
    void decl_var( const string& name ) {
      if( top().hasProperty( name ) ) 
        erro( "Variável já definida nesse escopo: " + name ); 
    
      top().setProp( name ) = Var();    
    }

    // Procura por uma variável para obter seu valor percorrendo a pilha de RA's do topo até o escopo global. 
    Var get_var( const string& name ) { 
      for( int i = v.size() - 1; i >= 0; --i )
        if( v[i].hasProperty( name ) ) 
          return v[i][name]; 
	      
      erro( "Variável não declarada: " + name );            

      return Var();
    }

    // Procura por uma variável para alterar seu valor percorrendo a pilha de RA's do topo até o escopo global. 
    void set_var( const string& name, Var& var ) { 
      for( int i = v.size() - 1; i >= 0; --i )
        if( v[i].hasProperty( name ) ) {
          v[i].setProp( name ) = var; 
          return;
        }
  
      erro( "Variável não declarada: " + name );            
    }

};

// Pilha de execução de operações - corresponde aos registradores em uma máquina convencional
Pilha pilha;

// Representa os registros de ativacao. O primeiro deles é o ambiente global.
PilhaRA pilha_ra; 

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
  { E, "&&" },
  { PUSH_ESC, "<{ (pushEsc)" },
  { POP_ESC, "}> (popEsc)"}
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

ostream& operator << ( ostream& o, const map<string,Var>& v ) {
  for( auto x : v ) 
    cout << "|" << x.first << " ==> " << x.second << "|" << endl;
  
  return o;
}

inline ostream& operator << ( ostream& o, const Pilha& v ) {
  return v.print( o ); 
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
  { "has_property", []() { auto p = pilha.pop2(); pilha.push( p.second.hasProperty( p.first.toString() ) ); } },
  { "to_string", []() { pilha.push( pilha.pop().toString() ); } },
  { "print", []() { cout << pilha.pop(); } },
  { "println", []() { cout << pilha.pop() << endl; } }
};

const Var undefined;

inline void create_global_context() {
  pilha_ra.push( newObject() );
  pilha_ra.decl_var( "undefined" );
}

int oldPC = 0;

void erro( string msg ) {
  cerr << "=== Erro: " << msg << " ===" <<endl;
  cerr << "=== Instrução: " << oldPC << " ===" << endl;
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
 
  online_judge = true;

  if( !online_judge )
    cout << codigo << endl;
    
  cout << "=== Console ===" << endl;

  create_global_context();
  
  while( !fim ) {
    if( debug ) {
      cout << "=== Instrução " << PC << ": " << codigo[PC] << " ===" << endl;
      cout << "=== Vars ===" << endl << pilha_ra;
      cout << "=== Pilha ===" << endl << pilha;
    }
    
    oldPC = PC;
    Codigo instrucao = codigo.at( PC++ );
    
    if( instrucao.index() == 0 )
      try {
	switch( get<0>( instrucao ) ) {
	  
	  case NEW_OBJECT: pilha.push( newObject() ); break;
	  case NEW_ARRAY: pilha.push( newArray() ); break;
	  case GET_PROP: p = pilha.pop2(); pilha.push( p.first[p.second] ); break;
	  case SET_PROP: topo = pilha.pop(); p = pilha.pop2(); p.first.setProp( p.second ) = topo; pilha.push( topo ); break;
	  case OBJ_SET_PROP: topo = pilha.pop(); p = pilha.pop2(); p.first.setProp( p.second ) = topo; pilha.push( p.first ); break;

	  case GOTO: 
	    topo = pilha.pop(); 
	    if( topo.isNumber() ) 
	      PC = topo.asInt(); 
	    else
	      if( func.find( topo.asString() ) != func.end() )
		func[topo.asString()]();
	      else
		erro( "Função interna não definida: " + topo.asString() );	    
	    break;
	  
	  case POP: pilha.pop(); break;
	  
	  case LET: {
            pilha_ra.decl_var( pilha.pop().asString() );
	    break;	    
	  }
	  
	  case GET: pilha.push( pilha_ra.get_var( pilha.pop().asString() ) ); break;

	  case SET: {
	    p = pilha.pop2();
            pilha_ra.set_var( p.first.asString(), p.second );
            pilha.push( p.second );
	    
	    break;
	  }
	  
	  case CALL_FUNC: {
	    Var ra = newObject();
	    Var args = newArray();

	    p = pilha.pop2();	 
            if( !p.first.isInt() )
              throw Var::newErro( "Essa variável deveria ser um número inteiro indicando o número de parâmetros passados para a função: " + p.first.toString() );

            if( !p.second.isFunction() )
              throw Var::newErro( "Essa variável deveria ser um objeto com o endereço da função em '&funcao': " + p.second.toString() );

	    ra.setProp( "&retorno" ) = PC;
	    ra.setProp( "arguments" ) = args;
	    
	    for( int i = p.first.asInt() - 1; i >= 0; i-- )
	      args.setProp( i ) = pilha.pop(); 
	      
	    pilha_ra.push( ra );
	    PC = p.second["&funcao"].asInt(); // Falta a captura (closure) 
	    break;
	  }

          case PUSH_ESC: {
            pilha_ra.push( newObject() );
            break;
          } 

          case POP_ESC: {
            pilha_ra.pop();
            break;
          } 
	  
	  case RET_FUNC: {
	    int endereco = pilha.pop().asInt(); 
	    PC = endereco;
	    pilha_ra.pop();
	    break;
	  }
	  
	  case JUMP_TRUE: p = pilha.pop2(); if( p.first.asBool() ) PC = p.second.asInt(); break;
	  
	  case E    : p = pilha.pop2(); pilha.push( p.first && p.second ); break;
	  case OU   : p = pilha.pop2(); pilha.push( p.first || p.second ); break;
	  case ME_IG: p = pilha.pop2(); pilha.push( p.first <= p.second ); break;
	  case MA_IG: p = pilha.pop2(); pilha.push( p.first >= p.second ); break;
	  case DIF  : p = pilha.pop2(); pilha.push( p.first != p.second ); break; 
	  case IGUAL: p = pilha.pop2(); pilha.push( p.first == p.second ); break;
	  case '+'  : p = pilha.pop2(); pilha.push( p.first + p.second ); break;
	  case '-'  : p = pilha.pop2(); pilha.push( p.first - p.second ); break;
	  case '*'  : p = pilha.pop2(); pilha.push( p.first * p.second ); break;
	  case '/'  : p = pilha.pop2(); pilha.push( p.first / p.second ); break;
	  case '%'  : p = pilha.pop2(); pilha.push( p.first % p.second ); break;
	  case '<'  : p = pilha.pop2(); pilha.push( p.first < p.second ); break;
	  case '>'  : p = pilha.pop2(); pilha.push( p.first > p.second ); break;
	  case '!'  : pilha.push( !pilha.pop() ); break;

	  case HALT: fim = true; break;
	    
	  default:
	    erro( string( "Instrução inválida: " ) + (char) get<0>( instrucao ) );
        }
      }
      catch( const bad_variant_access& e ) {
	erro( string( "Parâmetro para instrução com tipo inválido: " ) + e.what() );
      }
    else {
      pilha.push( get<1>( instrucao ) );
    }      
  }
  
  cout << "=== Vars ===" << endl << pilha_ra;
  if( pilha_ra.size() == 0 )
    cout << "O escopo global foi erroneamente desempilhado. " << endl; 
  cout << "=== Pilha ===" << endl << pilha;
  
  return 0;
}
catch( Var::Erro e ) {
  erro( e() );
}
