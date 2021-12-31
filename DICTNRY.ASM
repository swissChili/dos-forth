;;; Dictionary manipulation & memory management words

	;; ( addr len -- entry? )
	DEFWORD_RAW FIND, 'FIND'
	POP CX						; String length
	POP DI						; Start pointer
	MOV BX, WORD [VAR_LATEST]

.LOOP:
	;; BX and DI are clobbered
	PUSH BX
	PUSH DI
	CALL WORD_MATCHES
	POP DI
	POP BX

	TEST AX, AX
	JNZ .MATCH

	MOV BX, WORD [BX]			; Offset 0 = *LINK
	TEST BX, BX
	JNZ .LOOP					; If BX is 0 (end) fall through
	
.MATCH:
	PUSH BX						; BX holds dict entry
	NEXT


	;; BX - Word
	;; CX - Length
	;; DI - Name
	;; 
	;; All three parameter registers may be clobbered.
	;; 
	;; Return: AX - 0 or 1
WORD_MATCHES:
	MOV AL, BYTE [BX + WORDSZ]	; Word length
	AND AL, LENGTH_MASK | HIDDEN_BIT
	CMP AL, CL

	JE .EQUAL

	XOR AX, AX
	RET

.EQUAL:
	PUSH SI
	LEA SI, [BX + 3]			; Point to the dict entry name

.LOOP:
	CMPSB
	JNE .END
	LOOP .LOOP

	MOV AX, 1
	POP SI
	RET

.END:
	XOR AX, AX
	POP SI
	RET


	;; ( *addr -- value )
	DEFWORD_RAW GET, '@'
	POP BX
	PUSH WORD [BX]
	NEXT


	;; ( value *addr -- )
	DEFWORD_RAW SET, '!'
	POP BX
	POP AX
	MOV WORD [BX], AX
	NEXT


	DEFWORD_RAW GETCHAR, 'C@'
	POP BX
	XOR AX, AX
	MOV AL, BYTE [BX]
	PUSH AX
	NEXT


	;; Code field address
	DEFWORD_RAW CFA, '>CFA'
	POP BX
	ADD BX, 2

	XOR CH, CH
	MOV CL, BYTE [BX]			; String length
	AND CL, LENGTH_MASK
	ADD BX, CX					; Code field address
	ADD BX, 2					; 1 to round up, 1 to skip length
	AND BX, (~1)				; Zero the last bit


	PUSH BX
	NEXT


	DEFWORD_THREADED DFA, '>DFA'
	DW CFA, ADD2, EXIT


	DEFWORD_RAW CREATE, 'CREATE'
	POP CX 						; Length
	POP BX						; String

	CALL DO_CREATE
	NEXT

	;; CX = Length
	;; BX = Address
	;;
	;; AX, BX, CX, DX, DI clobbered
DO_CREATE:
	PUSH SI 					; Save SI

	MOV SI, BX
	MOV DI, [VAR_HERE]			; Top of dictionary
	MOV DX, DI					; New LATEST

	MOV AX, [VAR_LATEST]
	STOSW						; Link pointer

	MOV AX, CX					; Length
	STOSB

	REP MOVSB					; Copy string

	TEST DI, 1
	JZ .DONE

	INC DI						; Pad

.DONE:
	MOV [VAR_HERE], DI
	MOV [VAR_LATEST], DX

	POP SI
	RET


	DEFWORD_RAW COMMA, ','
	POP AX
	MOV DI, [VAR_HERE]
	STOSW
	MOV [VAR_HERE], DI
	NEXT


	;; Switch to interpret mode
	DEFWORD_RAW_IMMEDIATE LEFTBRACKET, '['
	MOV WORD [VAR_STATE], 0
	NEXT


	DEFWORD_RAW_IMMEDIATE RIGHTBRACKET, ']'
	MOV WORD [VAR_STATE], 1
	NEXT


	DEFWORD_RAW IMMEDIATE, 'IMMEDIATE'
	MOV BX, [VAR_LATEST]
	XOR BYTE [BX + 2], IMMEDIATE_BIT
	NEXT


	;; LATEST HIDDEN
	DEFWORD_RAW HIDDEN, 'HIDDEN'
	POP BX
	XOR BYTE [BX + 2], HIDDEN_BIT
	NEXT


	;; HIDE DUP
	DEFWORD_THREADED HIDE, 'HIDE'
	DW _WORD, FIND, HIDDEN, EXIT


	DEFWORD_THREADED_IMMED TICK, "'"
	DW _WORD, FIND, CFA, EXIT


	DEFWORD_RAW BRANCH, 'BRANCH'
	LODSW
	ADD SI, AX
	NEXT


	DEFWORD_RAW ZEROBRANCH, '0BRANCH'
	POP DX
	LODSW
	TEST DX, DX
	JNZ .NOTZERO
	ADD SI, AX

.NOTZERO:
	NEXT


	DEFWORD_RAW LITSTRING, 'LITSTRING'
	LODSW						; Length
	PUSH SI
	ADD SI, AX
	INC SI						; Round up
	AND SI, (~1)
	PUSH AX
	NEXT


	DEFWORD_THREADED INTERPRET, 'INTERPRET'
	DW _WORD					; ( addr len )
	DW _2DUP, FIND				; ( addr len entry? )
	DW DUP						; ( addr len entry? entry? )
	DW ZEROBRANCH, 26			; ( addr len entry? ); jump to .NUM if
								; the entry was not found.

	DW CFA						; ( addr len cfa )

	DW SWAP, DROP				; ( addr cfa )
	DW SWAP, DROP				; ( cfa )
	DW STATE, GET				; ( cfa 0|1 )

	DW ZEROBRANCH, 4
	DW COMMA					; Add to HERE
	DW EXIT

.WORD_IMMED:
	DW EXECUTE					; ( )
	DW EXIT

.NUM:							; ( addr len 0 )
	DW DROP						; ( addr len )
	DW NUMBER					; ( number unparsed )
	DW ZEROBRANCH, 4			; ( number ); jump to .NUMOK

	DW BRANCH, 18				; jump to .FAILED

.NUMOK:
	;; ( number )
	DW STATE, GET				; ( number STATE )
	DW ZEROBRANCH, 8			; ( number )

	DW LITERAL, LITERAL			; ( number LITERAL )
	DW COMMA, COMMA				; ( )

.NUM_IMMED:						; ( number )
	DW EXIT

.FAILED:						; ( number )
	INCLUDE_STRING $, 'Word is neither defined nor a number'
	DW TYPE, CR					; ( number )
	DW DROP, EXIT 				; ( )


	DEFWORD_RAW EXECUTE, 'EXECUTE'
	POP AX
	MOV BX, AX
	JMP [BX]


	;; TODO: await newline
	DEFWORD_THREADED QUIT, 'QUIT'
	DW INTERPRET
	DW BRANCH, -6


	DEFWORD_THREADED COLON, ':'
	DW _WORD, CREATE
	DW LITERAL, DOCOL, COMMA
	DW LATEST, GET, HIDDEN
	DW RIGHTBRACKET
	DW EXIT


	DEFWORD_THREADED_IMMED SEMICOLON, ';'
	DW LITERAL, EXIT, COMMA
	DW LATEST, GET, HIDDEN
	DW LEFTBRACKET
	DW EXIT


	;; ( *entry -- len *string )
	DEFWORD_THREADED ENTRY_NAME, ''
	DW DUP						; ( *entry *entry )
	DW LITERAL, 2, PLUS			; ( *entry *len )
	DW GETCHAR					; ( *entry len )
	DW SWAP						; ( len *entry )
	DW LITERAL, 3, PLUS			; ( len *string )
	DW SWAP
	DW EXIT


	DEFWORD_THREADED SHOW_DICT, '.d'
	DW LATEST, GET				; ( *entry )
	DW DUP, ENTRY_NAME			; ( *entry len *string)
	DW TYPE, CR					; ( *entry )
	DW GET						; ( *prev-entry )
	DW DUP						; ( *prev-entry *prev-entry )
	DW ZEROBRANCH, 2
	DW BRANCH, -24				; Back to start!
	DW EXIT
