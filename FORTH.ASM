	;; FORTH.ASM -- Forth system for Microsoft (R) DOS

	BITS 16

	;; DOS loads .COM executables here
	ORG 100h

	%INCLUDE "DOS.ASM"
	
;;; MACROS ;;;

	;; Step indirect threaded code to next word. Call this in a raw
	;; word to effectively return. In an interpreted word SI first
	;; needs to be reset to the calling value.
	%MACRO NEXT 0
	LODSW
	MOV BX, AX						; [ax] is invalid in 16 bits
	JMP [BX]
	%ENDMACRO


	;; Push register operand to return stack
	%MACRO RSPUSH 1
	SUB BP, WORDSZ
	MOV [BP], %1
	%ENDMACRO


	;; Pop from return stack to register operand
	%MACRO RSPOP 1
	MOV %1, [BP]
	ADD BP, WORDSZ
	%ENDMACRO


	;; Used for the compile-time dictionary linked list. Not used at
	;; runtime.
	%DEFINE LINK 0


	IMMEDIATE_BIT EQU 1 << 6
	HIDDEN_BIT EQU 1 << 5
	LENGTH_MASK EQU 0b11111


	;; Define a threaded word. The arguments should be the symbol for
	;; the word, followed by the string version. e.g.:
	;; 
	;; DEFWORD DUP, 'DUP', IMMEDIATE_BIT
	%MACRO DEFWORD 3
	ALIGN 2

WORD_%1:
	DW LINK
	%DEFINE LINK WORD_%1
	DB WORDLEN_%1 | %3			; Length | Flags

NAME_%1:
	DB %2,
	WORDLEN_%1 EQU $ - NAME_%1

	ALIGN 2
	
%1:
	%ENDMACRO


	%MACRO DEFWORD_THREADED 2
	DEFWORD %1, %2, 0
	DW DOCOL
	%ENDMACRO


	%MACRO DEFWORD_THREADED_IMMED 2
	DEFWORD %1, %2, IMMEDIATE_BIT
	DW DOCOL
	%ENDMACRO


	;; Same as DEFWORD_THREADED but this time with raw code
	%MACRO DEFWORD_RAW 2
	DEFWORD %1, %2, 0
	DW INTRAW					; Raw interpreter codeword

	;; Callable from assembly
CODE_%1:
	%ENDMACRO


	%MACRO DEFWORD_RAW_IMMEDIATE 2
	DEFWORD %1, %2, IMMEDIATE_BIT
	DW INTRAW

	;; Callable from assembly
CODE_%1:
	%ENDMACRO


	;; DEFVAR name, 'name'
	;; dw 0
	%MACRO DEFVAR 2
	DEFWORD_RAW %1, %2
	PUSH VAR_%1
	NEXT

VAR_%1:
	%ENDMACRO

	%MACRO DEFCONST 3
	DEFWORD_RAW %1, %2
	PUSH CONST_%1
	NEXT
	CONST_%1 EQU %3
	%ENDMACRO


	%MACRO INCLUDE_STRING 2
	DW LITSTRING
	DW STRINGLEN_%1
.BEFORE_STRING_%1:
	DB %2
	STRINGLEN_%1 EQU $ - .BEFORE_STRING_%1
	ALIGN WORDSZ
	%ENDMACRO


	;; TODO: This doesn't work for some reason
	%MACRO RELATIVE_ADDRESS 1
	DW (%1 - $)
	%ENDMACRO


;;; PROGRAM CODE ;;;

_START:
	;; Progran begins
	MOV BP, SP
	SUB BP, 1024				; why can't I use SP as a base for
								; load effective address?
	MOV SI, INDIRECT_START
	NEXT

	ALIGN 2


	;; DO COLon definition -- Codeword for indirect threaded code
	;; ax: indirect execution address
DOCOL:	
	RSPUSH si
	ADD AX, WORDSZ				; Point to the first word address
	MOV SI, AX					; Enter the function body (set si)
	NEXT


	;; Interpret raw code (plain machine code)
INTRAW:
	ADD AX, WORDSZ
	JMP AX


INDIRECT_START:	
	DW SETUP 
	DW QUIT
	DW BYE


SETUP:
	DW INTRAW

	MOV DX, MSG
	WRITESOUT

	NEXT

LITERAL:
	DW INTRAW

	LODSW						; Load the next word
	PUSH AX

	NEXT


EXIT:
	DW INTRAW
	RSPOP SI
	NEXT

TEST_PRINTING:
	DW INTRAW
	MOV AX, 5723
	JMP DOT_INT
	

	DEFWORD_RAW BYE, 'BYE'
	FLUSH
	QUIT_PROC


	DEFWORD_RAW LIT, 'LIT'
	LODSW 						; Read next word from input to AX
	PUSH AX
	NEXT


	DEFWORD_RAW DROP, 'DROP'
	ADD SP, WORDSZ
	NEXT


	DEFWORD_RAW SWAP, 'SWAP'
	POP AX
	POP BX
	PUSH AX
	PUSH BX
	NEXT


	DEFWORD_RAW DUP, 'DUP'
	;; This is stupid, [SP] is invalid
	POP AX
	PUSH AX
	PUSH AX
	NEXT


	DEFWORD_RAW PLUS, '+'
	POP AX
	POP BX
	ADD AX, BX
	PUSH AX
	NEXT


	DEFWORD_RAW MINUS, '-'		; ( DX AX -- DX-AX )
	POP AX
	POP DX
	SUB DX, AX
	PUSH DX
	NEXT


	DEFWORD_RAW ADD1, '1+'
	POP AX
	ADD AX, 1
	PUSH AX
	NEXT


	DEFWORD_RAW ADD2, '2+'
	POP AX
	ADD AX, 2
	PUSH AX
	NEXT


	;; This kind of sucks
	DEFWORD_RAW _2DUP, '2DUP'	; ( a b -- a b a b )
	POP AX
	POP BX
	PUSH BX
	PUSH AX
	PUSH BX
	PUSH AX
	NEXT
	

	%INCLUDE "IOWORDS.ASM"
	%INCLUDE "DICTNRY.ASM"
	
;;; LATE-INIT VARIABLES ;;;
	DEFVAR STATE, 'STATE'
	DW 0						; Interpret
	
	DEFVAR HERE, 'HERE'
	DW HERE_START
	
	;; LATEST must be the last word defined in FORTH.ASM!
	DEFVAR LATEST, 'LATEST'
	DW LINK
	

;;; PROGRAM DATA ;;;
	MSG DB 'DOS FORTH', 0Dh, 0Ah, '$'


;;; FREE DATA ;;;
HERE_START:
