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


	;; ( char address -- )
	DEFWORD_RAW SETCHAR, 'C!'
	POP BX
	POP AX
	MOV BYTE [BX], AL
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


	;; ( *a *b num -- )
	;; Copy NUM bytes from A to B
	DEFWORD_RAW CMOVE, 'CMOVE'
	RSPUSH SI
	POP CX
	POP DI
	POP SI
	REP MOVSB
	RSPOP SI
	NEXT


	;; ( a -- b )
	;; Round up to even number
	DEFWORD_RAW ROUND_EVEN, 'ROUND-EVEN'
	POP AX
	INC AX
	AND AX, (~1)
	PUSH AX
	NEXT


	;; ( start length -- )
	DEFWORD_RAW CMOVE_HERE, 'CMOVE,'
	POP CX
	RSPUSH SI
	POP SI
	MOV DI, [VAR_HERE]
	REP MOVSB
	MOV [VAR_HERE], DI
	RSPOP SI
	NEXT


	DEFWORD_THREADED CREATE, 'CREATE'
	DW HERE, GET				; ( *here )
	DW _WORD					; ( *here *string length )
	DW LATEST, GET				; ( *here *string length link )
	DW COMMA, DUP, CHAR_COMMA	; ( *here *string length )
	DW CMOVE_HERE				; ( *here )
	DW HERE, GET				; ( *here *here[new] )
	DW ROUND_EVEN				; ( here[new,even] )
	DW HERE, SET				; ( *here )
	DW LATEST, SET				; ( )
	DW EXIT


	DEFWORD_RAW COMMA, ','
	POP AX
	MOV DI, [VAR_HERE]
	STOSW
	MOV [VAR_HERE], DI
	NEXT


	DEFWORD_RAW CHAR_COMMA, 'C,'
	POP AX
	MOV DI, [VAR_HERE]
	STOSB
	MOV [VAR_HERE], DI
	NEXT


	;; Switch to interpret mode
	DEFWORD_RAW_IMMEDIATE LEFTBRACKET, '['
	MOV WORD [VAR_STATE], 0
	NEXT


	DEFWORD_RAW RIGHTBRACKET, ']'
	MOV WORD [VAR_STATE], 1
	NEXT


	DEFWORD_RAW_IMMEDIATE IMMEDIATE, 'IMMEDIATE'
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


	;; ( entry -- type )
	;; 0 = immediate; 1 = normal
	DEFWORD_THREADED GET_WORD_TYPE, 'WORD-TYPE'
	DW LITERAL, 2, PLUS			; ( entry+2 )
	DW GETCHAR					; ( length/flags )
	DW LITERAL, IMMEDIATE_BIT	; ( length/flags IMMEDIATE_BIT )
	DW AND						; ( 1=immediate;0=normal )
	DW LITERAL, IMMEDIATE_BIT
	DW XOR						; Toggle the bit
	DW EXIT


	DEFWORD_THREADED INTERPRET, 'INTERPRET'
	DW _WORD					; ( addr len )
	DW _2DUP, FIND				; ( addr len entry? )
	DW DUP						; ( addr len entry? entry? )
	DW ZEROBRANCH				; ( addr len entry? )
	RELATIVE_ADDRESS .NUM		; FIND returned 0

	DW SWAP, DROP, SWAP, DROP	; ( entry )
	DW DUP, CFA					; ( entry cfa )

	DW SWAP						; ( cfa entry )
	DW GET_WORD_TYPE			; ( cfa immediate? )

	DW STATE, GET				; ( cfa immediate? interpreting? )
	;; In either case evaluate
	DW ZEROBRANCH				; ( cfa immediate? )
	RELATIVE_ADDRESS .WORD_IMMED
	DW ZEROBRANCH				; ( cfa )
	RELATIVE_ADDRESS .WORD_COMPILE_IMMED

	;; Compile the word
	DW COMMA					; Add to HERE
	DW EXIT

.WORD_IMMED:					; ( cfa immediate? )
	DW DROP						; ( cfa )
.WORD_COMPILE_IMMED:
	DW EXECUTE					; ( )
	DW EXIT

.NUM:							; ( addr len 0 )
	DW DROP						; ( addr len )
	DW NUMBER					; ( number unparsed )
	DW ZEROBRANCH				; ( number )
	RELATIVE_ADDRESS .NUMOK

	INCLUDE_STRING 'Word is neither defined nor a number'
	DW TYPE, CR					; ( number )
	DW DROP, EXIT 				; ( )

.NUMOK:
	;; ( number )
	DW STATE, GET				; ( number STATE )
	DW ZEROBRANCH				; ( number )
	RELATIVE_ADDRESS .NUM_IMMED

	DW LITERAL, LITERAL			; ( number LITERAL )
	DW COMMA, COMMA				; ( )

.NUM_IMMED:						; ( number ) or ( )
	DW EXIT


	;; Jump to the word specified by the CFA on the stack
	DEFWORD_RAW EXECUTE, 'EXECUTE'
	POP AX
	MOV BX, AX
	JMP [BX]


	;; TODO: await newline
	DEFWORD_THREADED QUIT, 'QUIT'
.START:
	DW INTERPRET
	DW BRANCH
	RELATIVE_ADDRESS .START


	DEFWORD_THREADED COLON, ':'
	DW CREATE
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
	DEFWORD_THREADED ENTRY_NAME, 'ENTRY->NAME'
	DW DUP						; ( *entry *entry )
	DW LITERAL, 2, PLUS			; ( *entry *len/flags )
	DW GETCHAR					; ( *entry len/flags )
	DW LITERAL, LENGTH_MASK, AND ; ( *entry len )
	DW SWAP						; ( len *entry )
	DW LITERAL, 3, PLUS			; ( len *string )
	DW SWAP
	DW EXIT


	DEFWORD_THREADED SHOW_DICT, 'WORDS'
	DW LATEST, GET				; ( *entry )
.LOOP:
	DW DUP, ENTRY_NAME			; ( *entry len *string)
	DW TYPE, SPACE				; ( *entry )
	DW GET						; ( *prev-entry )
	DW DUP						; ( *prev-entry *prev-entry )
	DW ZEROBRANCH
	RELATIVE_ADDRESS .DONE

	DW BRANCH					; Back to start!
	RELATIVE_ADDRESS .LOOP
.DONE:
	DW CR, EXIT


	DEFWORD_RAW SHOW_STACK, '.S'
	MOV CX, WORD [CONST_SP_INITIAL]
	RSPUSH SI
	STD							; Go backwards

	MOV SI, CX					; Going down
	SUB SI, 2					; Just below it
	SUB CX, SP					; Number of bytes on the stack
	JLE .DONE					; Below stack bottom (oops!)
	SHR CX, 1					; Divide by 2 -- number of cells

.LOOP:
	LODSW
	PUSH CX						; Clobbered
	CALL DOT_INT
	POP CX

	MOV DX, ' '
	WRITECOUT

	LOOP .LOOP

.DONE:
	MOV DX, CRLF_MSG
	WRITESOUT
	
	RSPOP SI
	CLD
	NEXT


	DEFWORD_THREADED DUMP_IMAGE, 'DUMP-IMAGE'
	DW LITERAL, F_WRITE			; ( *string len flags )
	DW OPEN_FILE				; ( handle )
	DW DUP						; ( handle handle )
	DW LITERAL, 100h			; ( handle handle *start )
	DW SWAP, HERE, GET			; ( handle *start handle *here )
	DW SWAP, FILE_WRITE_RANGE	; ( handle )
	DW CLOSE_FILE				; ( )
	DW EXIT
