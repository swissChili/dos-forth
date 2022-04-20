\ Core words for DOS FORTH

: NIP SWAP DROP ;
: / /MOD NIP ;
: MOD /MOD DROP ;

: LITERAL IMMED ' LIT , , ;
: [COMPILE] IMMED WORD FIND >CFA , ;
: RECURSE IMMED LATEST , >CFA , ;

\ Control structures

\ cond IF <*b0> true ELSE false THEN rest
: IF ( -- *then ) IMMED ' 0BRANCH , HERE @ 0 , ;

: THEN ( *then -- *then ) IMMED
  DUP HERE @ SWAP ( *then *then *here )
  SWAP - ( *then *here-*then )
  SWAP ! ;

: ELSE ( *then -- *here ) IMMED
  ' BRANCH ,
  HERE @ ( *then *ph )
  0 ,
  SWAP ( *ph *then )
  DUP ( *ph *then *then )
  HERE @ ( *ph *then *then *here )
  SWAP - ( *ph *then diff )
  SWAP ! ( *ph ) ;

DUMP-IMAGE FORTH.COM
BYE
