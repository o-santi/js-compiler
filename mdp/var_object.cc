#include <iostream>
#include <string>
#include <type_traits>
#include <vector>
#include <map>
#include <memory>
#include <functional>

#include <variant>
#include <sstream>

using namespace std;

bool online_judge = false;

template<class... Ts> struct composer : Ts... { using Ts::operator()...; };
template<class... Ts> composer(Ts...) -> composer<Ts...>;

inline string trim( string s, const char* t = " \t\n\r\f\v" ) {
  s.erase(0, s.find_first_not_of(t));
  s.erase(s.find_last_not_of(t) + 1);
  
  return s;
}

class Var {
public:
  static constexpr auto newErro = []( string st ) { return [st](){ return st; }; };

  class Undefined {};

  class Object {
  public:
    virtual ~Object() {}
    
    virtual void print( ostream& o ) const { 
      o << "{ ";
      ::for_each( atr.begin(), atr.end(), 
		  [&o]( auto x ){ 
		    if( online_judge && x.first == "&funcao" )
		      o << x.first << ": ##; "; 
		    else
		      o << x.first << ": " << x.second << "; "; 
		  } );
      o << "}";  }
    
    virtual Var executa( const Var& arg ) const { throw newErro( "Object não pode ser usada como função"  );  }  
    
    virtual Var& lvalue( const string& st ) { return atr[st]; }
    virtual Var rvalue( const string& st ) const { 
      if( auto x = atr.find( st ); x != atr.end() )
	return x->second;
      
      return Var(); 
    }
    
    virtual bool hasProperty( const string& nome ) const { return atr.find( nome ) != atr.end(); }
    
    virtual Var& lvalue( size_t n ) { throw newErro( "Object não pode ser usada como array" ); }
    virtual Var rvalue( size_t n ) const { throw newErro( "Object não pode ser usada como array" ); }
    
    virtual Var indexOf( const Var& valor ) const { throw newErro( "Object não pode ser usada como array" ); }
    virtual Var filter( const Var& functor ) const { throw newErro( "Object não pode ser usada como array" ); }
    virtual Var map( const Var& functor ) const { throw newErro( "Object não pode ser usada como array" ); }
    virtual Var forEach( const Var& functor ) const { throw newErro( "Object não pode ser usada como array" ); }

    virtual Var push( const Var& valor ) { throw newErro( "Object não pode ser usada como array" ); }
    virtual Var pop() { throw newErro( "Object não pode ser usada como array" ); }
    virtual Var length() const { throw newErro( "Object não pode ser usada como array" ); }
   
  private:
    ::map<string,Var> atr; 
  };

  class Array: public Object {
  public:
    Array(): a() {}

    virtual void print( ostream& o ) const {
      int i = 0;
      o << "[ "; 
      ::for_each( a.begin(), a.end(), [&o,&i]( auto x ){ o << x << " "; } );
      o << "]"; 
    }
        
    virtual Var& lvalue( size_t n ) { 
      if( a.size() <= n )
	a.resize( n + 1 );
      
      return a[n];
    }
    
    virtual Var rvalue( size_t n ) const { 
      if( a.size() <= n )
	return Var();
      else
        return a[n];
    }
    
    Var rvalue( const string& st ) const {
      if( st == "size" ) 
	return (int) a.size();
    
      return Object::rvalue( st ); 
    }

    virtual Var indexOf( const Var& valor ) const;
    
    virtual Var filter( const Var& functor ) const { 
      Array* result = new Array();
      
      for( const auto& x : a )
	if( functor( x ).asBool() )
	  result->a.push_back( x );
      
      return Var( result );
    }
    
    virtual Var map( const Var& functor ) const { 
      Array* result = new Array();
      
      for( const auto& x : a )
        result->a.push_back( functor( x ) );
      
      return Var( result );      
    }
    
    virtual Var forEach( const Var& functor ) const {
      for( const auto& x : a )
        functor( x );
      
      return Var();
    }

    virtual Var push( const Var& valor ) { 
      a.push_back( valor );
      return Var();
    }
    
    virtual Var pop() { 
      if( a.size() > 0 ) {
	Var p = a.back();
	a.pop_back();
	return p;
      }
      else
	return Var();
    }
    
    virtual Var length() const { 
      return (int) a.size();
    }

  private:
    vector<Var> a;
  };
   
private:
  template <typename F>
  class Function: public Object {
  public:
    Function( F f ): f(f) {}

    virtual void print( ostream& o ) const { o << "function"; }
    
    virtual Var executa( const Var& arg ) const { 
      if constexpr( is_invocable< F, Var >::value ) 
        if constexpr( is_same_v< invoke_result_t< F, Var >, void > ) {
	  invoke( f, arg );
	  return Var();
        }
        else
	  return invoke( f, arg );
      else {
        return selector( composer{ f, undef }, arg );	
      }  
    }
    
  private:
    F f;
  };
   
  typedef variant<Undefined,bool,char,int,double,string,shared_ptr<Object>> Variant;
  
public:
  enum TIPO { UNDEFINED, BOOL, CHAR, INT, DOUBLE, STRING, OBJECT };
  
  typedef invoke_result< decltype(newErro), string >::type Erro;
  
  Var(): v() {}
  Var( const char* st ): v( string(st) ) {}
  Var( bool v ): v(v) {}
  Var( char v ): v(v) {}
  Var( int v ): v(v) {}
  Var( double v ): v(v) {}
  Var( string v ): v(v) {}
  Var( Object* v ): v( shared_ptr<Object>( v ) ) {}
  Var( Array* v ): v( shared_ptr<Object>( v ) ) {}
  
  template <typename T>
  Var( T func ): v( shared_ptr<Object>( new Function( func ) ) ) {}
  
  bool hasProperty( const string& nome ) const { 
    return visit( composer{
      [&nome]( const shared_ptr<Object>& obj ) -> bool { return obj->hasProperty( nome ); },
      [this]( auto ) -> bool { throw newErro( "Essa variável não é um objeto: " + asString() ); }
    }, v );    
  }

  
  Var operator()( const Var& arg ) const {
    return visit( composer{
      [&arg]( const shared_ptr<Object>& obj ) -> Var { return obj->executa( arg ); },
      [this]( auto ) -> Var { throw newErro( "Essa variável não pode ser usada como função: " + asString() ); }
    }, v );
  }
  
  Var& setProp( const Var& index ) { 
    if( v.index() != OBJECT )
      throw newErro( "Essa variável não é um objeto: " + asString() );
    
    return visit( composer{
      [this]( int n ) -> Var& {  return n < 0 ? get<OBJECT>( v )->lvalue( trim( to_string( n ) ) ) : get<OBJECT>( v )->lvalue( n ); },
      [this]( Undefined n ) -> Var& {  return get<OBJECT>( v )->lvalue( string( "undefined" ) ); },
      []( const shared_ptr<Object>& obj )->Var& { throw newErro( "O índice não pode ser um objeto" ); }, 
      [this]( auto x ) -> Var& { return get<OBJECT>( v )->lvalue( Var( x ).toString() ); }
    }, index.v ); 
  }
 
  const Var operator []( const Var& index ) const  { 
    if( v.index() != OBJECT )
      throw newErro( "Essa variável não é um objeto: " + asString() );
    
    return visit( composer{
      [this]( int n ) -> Var { return n < 0 ? get<OBJECT>( v )->rvalue( trim( to_string( n ) ) ) : get<OBJECT>( v )->rvalue( n ); },
      [this]( Undefined n ) -> Var {  return get<OBJECT>( v )->rvalue( string( "undefined" ) ); },
      []( const shared_ptr<Object>& obj ) -> Var { throw newErro( "O índice não pode ser um objeto" ); }, 
      [this]( auto x ) -> Var { return get<OBJECT>( v )->rvalue( Var( x ).toString() ); }
    }, index.v ); 
  } 
    
  ostream& print( ostream& o ) const {
    visit( composer{ 
      [&o]( const Undefined& ) { o << "undefined"; }, 
      [&o]( bool b ) { o << (b ? "true" : "false"); }, 
      [&o]( const shared_ptr<Object>& obj ) { obj->print( o ); }, 
      [&o]( const auto& x ) { o << x; } 
    }, v );
    
    return o;
  }
  
  const Var& operator = ( bool v ) { this->v = v; return *this; }
  const Var& operator = ( char v ) { this->v = v; return *this; }
  const Var& operator = ( int v ) { this->v = v; return *this; }
  const Var& operator = ( double v ) { this->v = v; return *this; }
  const Var& operator = ( const string& st ) { this->v = st; return *this; }
  const Var& operator = ( const char* st ) { this->v = string( st ); return *this; }
  
  const Var& operator = ( Object *o ) { v = shared_ptr<Object>( o ); return *this; }
  const Var& operator = ( Array *o ) { v = shared_ptr<Object>( o ); return *this; }
  
  template <typename F>
  const Var& operator = ( F f ) {
    this->v = shared_ptr<Object>( new Function<F>( f ) );
    return *this;
  }

  static constexpr auto undef = composer{ [](const auto&, const auto&){ return Var(); }, [](const auto&){ return Var(); } };
  
  static constexpr auto adicao = composer{
    []( int a, int b ){ return a + b; },
    []( double a, double b ){ return a + b; },
    []( char a, char b ){ return string( 1, a ) + b; },
    []( const string& a, const string& b ){ return a + b; },

    []( const string& a, int b ){ return a + to_string( b ); },
    []( int a, const string& b ){ return to_string( a ) + b; },

    []( char a, const string& b ){ return a + b; },
    []( const string& a, char b ){ return a + b; },
    
    []( int a, double b ){ return (double)(a + b); },
    []( double a, int b ){ return (double)(a + b); },

    []( int a, char b ){ return a + b; },
    []( char a, int b ){ return a + b; },
   
    []( int a ){ return a; },
    []( double a ){ return a; },
    []( char a ){ return a; },

    undef
  };
    
  static constexpr auto subtracao = composer{
    []( char a, char b ){ return a - b; },
    []( int a, int b ){ return a - b; },
    []( double a, double b ){ return a - b; },
    
    []( int a, double b ){ return a - b; },
    []( double a, int b ){ return a - b; },

    []( int a, char b ){ return a - b; },
    []( char a, int b ){ return a - b; },
    
    []( int a ){ return - a; },
    []( double a ){ return - a; },
    []( char a ){ return - a; },
  
    undef
  };
    
  static constexpr auto multiplicacao = composer{
    []( int a, int b ){ return a * b; },
    []( double a, double b ){ return a * b; },
    
    []( int a, double b ){ return a * b; },
    []( double a, int b ){ return a * b; },

    undef
  };
    
  static constexpr auto modulo = composer{
    []( char a, char b ){ return a % b; },
    []( int a, int b ){ return a % b; },

    []( int a, char b ){ return a % b; },
    []( char a, int b ){ return a % b; },
    undef
  };
    
  static constexpr auto divisao = composer{
    []( int a, int b ){ return a / b; },
    []( double a, double b ){ return a / b; },
    
    []( int a, double b ){ return a / b; },
    []( double a, int b ){ return a / b; },

    undef
  };
  
  static constexpr auto menor = composer{
    []( bool a, bool b ){ return a < b; },
    []( char a, char b ){ return a < b; },
    []( int a, int b ){ return a < b; },
    []( double a, double b ){ return a < b; },
    []( const string& a, const string& b ){ return a < b; },

    []( char a, string b ){ return string( 1, a ) < b; },
    []( string a, char b ){ return a < string( 1, b ); },
    
    []( int a, double b ){ return a < b; },
    []( double a, int b ){ return a < b; },

    []( int a, char b ){ return a < b; },
    []( char a, int b ){ return a < b; },
   
    undef
  };

  static constexpr auto igual = composer{
    []( Undefined a, Undefined b ){ return true; },
    []( bool a, bool b ){ return a == b; },
    []( char a, char b ){ return a == b; },
    []( int a, int b ){ return a == b; },
    []( double a, double b ){ return a == b; },
    []( const string& a, const string& b ){ return a == b; },

    []( char a, string b ){ return string( 1, a ) == b; },
    []( string a, char b ){ return a == string( 1, b ); },
    
    []( int a, double b ){ return a == b; },
    []( double a, int b ){ return a == b; },

    []( int a, char b ){ return a == b; },
    []( char a, int b ){ return a == b; },
   
    undef
  };

  static constexpr auto ou = composer{
    []( bool a, bool b ){ return a || b; },   
    undef
  };
    
  static constexpr auto e = composer{
    []( bool a, bool b ){ return a && b; },   
    undef
  };
        
  static inline constexpr Var selector( auto operador, const Var& a, const Var& b ) {
    return selector( [&b,operador](const auto& av) -> Var { 
      return selector( [&av,operador](const auto& bv) -> Var { 
	return Var( operador( av, bv ) ); 
      }, b ); 
    }, a );
  }

  static Var selector( auto operador, const Var& a ) {
    // Essa opção demora muito para compilar.
    // return visit( [operador](const auto& av) -> Var { return Var( operador( av ) ); } , a.v );
    // Usar uma implementação alternativa
    switch( a.v.index() ) {
      case UNDEFINED: return operador( get<UNDEFINED>( a.v ) );
      case BOOL: return operador( get<BOOL>( a.v ) );
      case CHAR: return operador( get<CHAR>( a.v ) );
      case INT: return operador( get<INT>( a.v ) );
      case DOUBLE: return operador( get<DOUBLE>( a.v ) );
      case STRING: return operador( get<STRING>( a.v ) );
      case OBJECT: return operador( get<OBJECT>( a.v ) );
      default:
	throw newErro( "Bug" );
    }
  }
  
  bool asBool() const {
    switch( v.index() ) {
      case UNDEFINED: return false;
      case BOOL: return get<BOOL>( v );
      case CHAR: return true;
      case INT: return get<INT>( v ) == 0 ? false: true;
      case DOUBLE: return get<DOUBLE>( v ) == 0.0 ? false : true;
      case STRING: return get<STRING>( v ).size() == 0 ? false: true;
      case OBJECT: return get<OBJECT>( v ).get() == nullptr ? false: true;
      default:
	throw newErro( "Bug" );
    }    
  }
  
  string toString() const {
    stringstream str;

    print( str );
    
    return str.str();
  }  

  int asInt() const {
    if( v.index() != INT )
      throw newErro( "Essa variável não é um número inteiro: " + toString() );
      
    return get<INT>( v );
  }
  
  string asString() const {
    if( v.index() != STRING )
      throw newErro( "Essa variável não é uma string: " + toString() );
    
    return get<STRING>( v );
  }
  
  bool isNumber() const {
    switch( v.index() ) {
      case UNDEFINED: return false;
      case BOOL: return true;
      case CHAR: try {
	stod( string("") + get<CHAR>( v ) );
	return true;
      }
      catch( ... ) {
	return false;
      }
	
      case INT: return true;
      case DOUBLE: return get<DOUBLE>( v ) == 0.0 ? false : true;
      case STRING: if( get<STRING>( v ).size() == 0 )
	return true;
	else try {
	  stod( get<STRING>( v ) );
	  return true;
      }
      catch( ... ) {
	return false;
      } 
	
	return get<STRING>( v ).size() == 0 ? true : true;
      case OBJECT: return get<OBJECT>( v ).get() == nullptr ? true: false;
      default:
	throw newErro( "Bug" );
    }    
  }
  
  auto& get_object() {
    if( v.index() != OBJECT )
      throw newErro( "Essa variável não é um array: " + asString() );
    
    return get<OBJECT>( v );    
  }

  const auto& get_object() const {
    if( v.index() != OBJECT )
      throw newErro( "Essa variável não é um array: " + asString() );
    
    return get<OBJECT>( v );    
  }
  
  Var filter( const Var& functor ) const {
    return get_object()->filter( functor );
  }

  Var indexOf( const Var& valor ) const {
    return get_object()->indexOf( valor );
  }

  Var map( const Var& functor ) const {
    return get_object()->map( functor );
  }
  
  Var forEach( const Var& functor ) const {
    return get_object()->forEach( functor );
  }

  Var push( const Var& valor ) {
    return get_object()->push( valor );
  }
    
  Var pop() {
    return get_object()->pop();
  }
  
  Var length() const {
    return get_object()->length();
  }
  
private:
  Variant v;
};

inline ostream& operator << ( ostream& o, const Var& v ) { return v.print( o ); }
inline Var operator + ( const Var& a, const Var& b ) { return Var::selector( Var::adicao, a, b ); }

inline Var operator - ( const Var& a, const Var& b ) { return Var::selector( Var::subtracao, a, b ); }
inline Var operator * ( const Var& a, const Var& b ) { return Var::selector( Var::multiplicacao, a, b ); }
inline Var operator / ( const Var& a, const Var& b ) { return Var::selector( Var::divisao, a, b ); }
inline Var operator % ( const Var& a, const Var& b ) { return Var::selector( Var::modulo, a, b ); }
inline Var operator < ( const Var& a, const Var& b ) { return Var::selector( Var::menor, a, b ); }
inline Var operator || ( const Var& a, const Var& b ) { return Var::selector( Var::ou, a, b ); }
inline Var operator && ( const Var& a, const Var& b ) { return Var::selector( Var::e, a, b ); }

inline Var operator ! ( const Var& a ) { return !a.asBool(); }
inline Var operator - ( const Var& a ) { return Var::selector( Var::subtracao, a ); }
inline Var operator + ( const Var& a ) { return Var::selector( Var::adicao, a ); }

inline Var operator > ( const Var& a, const Var& b ) { return b<a; }
inline Var operator != ( const Var& a, const Var& b ) { return !Var::selector( Var::igual, a, b ); }
inline Var operator == ( const Var& a, const Var& b ) { return Var::selector( Var::igual, a, b ); }
inline Var operator >= ( const Var& a, const Var& b ) { return !(a<b); }
inline Var operator <= ( const Var& a, const Var& b ) { return !(b<a); }

inline Var Var::Array::indexOf( const Var& valor ) const {    
  for( unsigned i = 0; i < a.size(); i++ )
    if( (valor == a[i]).asBool() )
      return Var( (int) i );
  
  return -1;
}

inline Var::Object* newObject() {
  return new Var::Object();
}

inline Var::Array* newArray() {
  return new Var::Array();
}

typedef variant<int,Var> Codigo;

#ifdef DEBUG

//==============================================

int main() try {
  Var a = newArray();
  Var print = []( auto a ){ a.forEach( []( auto x ) { cout << x << ";"; } ); cout << endl; };
  
  for( int i = 0; i < 5; i++)
    a.push( i );
  
  print( a );
  
  cout << a.pop() << "," << a.pop() << ", tamanho: " << a.length() << endl;
  
  print( a );
}
catch( Var::Erro e ) {
  cout << e() << endl;
}

#endif
