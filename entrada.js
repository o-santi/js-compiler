function log( msg ) {
  msg asm{println # undefined};
}

function imprimeMdc( a = 36, b = 48, print = m => log( 'Saida: ' + m )  ) {
  if( b == 0 )
    print( a )
  else
    imprimeMdc( b, a%b, print );
}

imprimeMdc( 24, 18 );
imprimeMdc( 8, 4, log );
