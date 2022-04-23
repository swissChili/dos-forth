;;; Assembly definitions of built-in Forth words
;;; Assume this is included after all the relevant macros


;;; INPUT & OUTPUT ROUTINES ;;;
	;; Stack of input file pointers
	DEFVAR INP_S0, 'INP-S0'
KEY_INP_STACK:
	TIMES 32 DW 0

	;; Top of the stack
	DEFVAR INP_SP, 'INP-SP'
KEY_INP_STACKP:
	DW KEY_INP_STACK


	;; ( handle -- )
	DEFWORD_RAW SEEK_START, 'SEEK-START'
	XOR AL, AL
	POP BX
	XOR CX, CX
	XOR DX, DX
	SEEKF
	NEXT


	;; ( *str len -- )
	;; Opens the file specified by *str and len for reading and adds it
	;; to the input stack.
	DEFWORD_THREADED INCLUDED, 'INCLUDED'
	DW TO_RET, TO_RET			; ( ) [ len *str ]
	DW LITERAL, F_READ			; ( flags )
	DW FROM_RET, FROM_RET		; ( flags *str len ) [ ]
	DW OPEN_FILE_NAMED			; ( handle )
	DW DUP, SEEK_START			; ( handle )
	DW INP_SP					; ( handle *inp-sp )
	DW GET, ADD2				; ( handle inp-sp+2 )
	DW SWAP, OVER				; ( inp-sp+2 handle inp-sp+2 )
	DW SET						; ( inp-sp+2 )
	DW INP_SP					; ( inp-sp+2 *inp-sp )
	DW SET, EXIT				; ( )


	DEFWORD_THREADED INCLUDE, 'INCLUDE'
	DW _WORD, INCLUDED, EXIT
	

KEY_INP_BUF:
	DW 0
	
	;; Read a key from the input. If STDIN is blank wait for a key
	;; press.
	;;
	;; TODO: Keep an internal buffer until RETURN is pressed, allow
	;; some line editing.
	DEFWORD_RAW KEY, 'KEY'
	CALL READ_KEY
	PUSH AX
	NEXT

KEY_ERR_MSG DOS_STRING 'CF set'
KEY_END_MSG DOS_STRING 'EOF'
KEY_NO_ERR_MSG DOS_STRING 'No error'
KEY_GOT_CHAR_MSG DOS_STRING ' Read'
	
	;; This routine returns the key in AL, but Forth wants it on the
	;; stack, so we have a helper function.
	;; 
	;; Clobbers: BX, CX
	;; Return: AX
READ_KEY:
	MOV BX, [KEY_INP_STACKP]	; Address of current input file handle
	MOV BX, [BX]
	TEST BX, BX
	JZ .READ_STDIN				; If the file handle is 0

	MOV CX, 1					; We're reading 1 byte from a file
	MOV DX, KEY_INP_BUF			; Write to our temporary buffer
	READF

	JC .READ_ERR				; CF - general read error
	TEST AX, AX
	JZ .READ_ERR				; AX=0 - at EOF

	MOV AX, [KEY_INP_BUF]

	RET

.READ_ERR:
	MOV BX, [KEY_INP_STACKP]
	CLOSEF						; Close the input stream
	MOV [BX], WORD 0			; Reset **inp-sp 0
	MOV BX, [KEY_INP_STACKP]
	SUB BX, 2					; Pop off input stack
	MOV [KEY_INP_STACKP], BX
	JMP READ_KEY				; Re-try reading the key
	
.READ_STDIN:
	READCIN
	XOR AH, AH 					; We don't care about the scan code
	RET


	%MACRO WHITESPACE 2
	CMP %1, ' '
	JE %2

	CMP %1, 09h					; \t
	JE %2

	CMP %1, 0Ah 				; \n
	JE %2

	CMP %1, 0Dh 				; \r
	JE %2
	%ENDMACRO
	
	
	;; Read a word from the input, max 32 bytes. WORD is reserved in
	;; NASM sadly.
	DEFWORD_RAW _WORD, 'WORD'
READ_WORD:
	MOV DI, WORD_BUFFER

.START:
	;; First skip whitespace
	CALL READ_KEY				; Char in AL

	WHITESPACE AL, .START
	CMP AL, '\'
	JE .COMMENT

.LOOP:
	CMP AL, 'a'
	JL .STORE
	CMP AL, 'z'
	JG .STORE

	SUB AL, ('a' - 'A')			; To upper case

.STORE:
	STOSB 						; Buffer char

	CALL READ_KEY
	WHITESPACE AL, .DONE
	JMP .LOOP

.COMMENT:
	CALL READ_KEY
	CMP AL, ASCII_NEWLINE
	JE .START
	CMP AL, ASCII_RETURN
	JE .START

	JMP .COMMENT

.DONE:
	SUB DI, WORD_BUFFER 		; Length
	PUSH WORD_BUFFER
	PUSH DI

	NEXT


	DEFWORD_RAW_IMMEDIATE LPAREN, '('
.LOOP:
	CALL READ_KEY
	CMP AL, ')'
	JNE .LOOP
	NEXT


	;; ( string len -- num unparsed )
	DEFWORD_RAW NUMBER, 'NUMBER'
	POP DX						; Length
	POP BX						; Index
	ADD DX, BX					; End pointer
	XOR AX, AX					; The number

	XOR CX, CX					; CL - used for char

.LOOP:
	MOV CL, BYTE [BX]
	CMP CL, '0'
	JL .DONE
	CMP CL, '9'
	JG .DONE

	SUB CL, '0'
	MOV CH, 10					; This needs to be reset each time
								; which is annoying
	IMUL CH						; 8-bit IMUL operand means that the
								; result is just in AX, not extended
								; by DX. Perfect
	XOR CH, CH
	ADD AX, CX
	INC BX
	CMP BX, DX
	JL .LOOP
	
.DONE:
	SUB DX, BX					; Number of chars unread
	PUSH AX
	PUSH DX
	NEXT


	;; Emit a char from the stack
	DEFWORD_RAW EMIT, 'EMIT'
	POP DX
	WRITECOUT
	NEXT


	DEFWORD_RAW CR, 'CR'
	MOV DX, CRLF_MSG
	WRITESOUT
	NEXT


	DEFWORD_THREADED SPACE, 'SPACE'
	DW LITERAL, ' ', EMIT, EXIT


	DEFWORD_RAW TYPE, 'TYPE'
TYPE_STRING:
	POP CX						; Length
	POP BX						; Index
	ADD CX, BX					; End pointer

.LOOP:
	MOV DL, BYTE [BX]
	WRITECOUT

	INC BX
	CMP BX, CX
	JNE .LOOP

.DONE:
	NEXT


	;; ( n -- )
	DEFWORD_RAW DOT, '.'
	POP AX 						; The number
	CALL DOT_INT
	NEXT

	;; AX - number to print
	;; Clobbers: DX, BX, CX
DOT_INT:	
	TEST AX, AX
	JNZ .START

	MOV DX, '0'
	WRITECOUT
	RET
	
.START:
	MOV BX, 10					; The base

	;; TODO: BUG: Depending on this value there is a maximum number
	;; that this routine will format, which is weird. For the value of
	;; 7 it is 1280.
	MOV CX, 7
.LOOP:
	XOR DX, DX
	DIV BX						; AX = quotient; DX = remainder
	PUSH DX

	LOOP .LOOP

	MOV CX, 7
	XOR BX, BX					; At start
.REVERSE:
	POP DX
	OR BL, DL
	JZ .END

	ADD DL, '0'
	WRITECOUT

.END:
	LOOP .REVERSE

	RET


	;; Write a string to the PAD and 0-terminate it. For use with DOS
	;; I/O words that require ASCIZ strings.
	;;
	;; CX - string length
	;; BX - start of string
	;; Clobbers: none
	;; Returns: BX - address of temporary string
MAKE_STRING_ASCIZ:
	PUSH SI
	PUSH DI
	PUSH CX

	MOV SI, BX
	GET_PAD DI
	PUSH DI						; Save start of temp string
	REP MOVSB					; Copy bytes
	MOV BYTE [DI], 0			; 0-terminate
	POP BX						; Return start in BX

	POP CX
	POP DI
	POP SI

	RET

	;; ( flags *start len -- )
	DEFWORD_RAW CREATE_FILE_NAMED, 'CREATE-FILE-NAMED'
	POP CX						; Len
	POP BX						; Start
	CALL MAKE_STRING_ASCIZ
	POP CX						; Flags
	MOV DX, BX
	CREATF
	NEXT


	;; ( flags -- ) CREATE-FILE <file-name>
	DEFWORD_THREADED CREATE_FILE, 'CREATE-FILE'
	DW _WORD, CREATE_FILE_NAMED, EXIT


	;; ( flags *start len -- handle )
	DEFWORD_RAW OPEN_FILE_NAMED, 'OPEN-FILE-NAMED'
	POP CX						; Length
	POP BX						; Start
	CALL MAKE_STRING_ASCIZ
	MOV DX, BX					; ASCIZ string in DX
	POP AX						; Flags
	OPENF

	JC FILE_WRITE_ERROR
	PUSH AX
	NEXT

FILE_WRITE_ERROR:
	MOV DX, MSG_OPENF_FAILED
	WRITESOUT
	PUSH AX
	NEXT


	;; ( flags -- handle )
	DEFWORD_THREADED OPEN_FILE, 'OPEN-FILE'
	DW _WORD					; ( flags *str len )
	DW OPEN_FILE_NAMED
	DW EXIT


	DEFWORD_RAW CLOSE_FILE, 'CLOSE-FILE'
	POP BX
	CLOSEF
	NEXT


	;; Write word to file
	;; ( cell handle -- )
	DEFWORD_RAW FILE_COMMA, 'F,'
	POP BX						; Handle
	POP DX						; Data
	MOV WORD [FILE_WRITE_BUFFER], DX
	MOV DX, FILE_WRITE_BUFFER	; Address
	MOV CX, 2					; Length
	WRITEF
	JC FILE_WRITE_ERROR
	NEXT


	;;  ( byte handle -- )
	DEFWORD_RAW FILE_CHAR_COMMA, 'FC,'
	POP BX
	POP DX
	MOV BYTE [FILE_WRITE_BUFFER], DL
	MOV DX, FILE_WRITE_BUFFER
	MOV CX, 1
	WRITEF
	JC FILE_WRITE_ERROR
	NEXT


	;; ( *start *end handle -- )
	DEFWORD_RAW FILE_WRITE_RANGE, 'FWRITE-RANGE'
	POP BX
	POP CX						; End
	POP DX
	SUB CX, DX					; Get difference
	WRITEF
	NEXT


;;; DATA ;;;
	CRLF_MSG DB ASCII_RETURN, ASCII_NEWLINE, '$'
	MSG_OPENF_FAILED DB 'File error', ASCII_RETURN, ASCII_NEWLINE, '$'

	WORD_BUFFER TIMES 33 DB 0
	FILE_WRITE_BUFFER DW 0
WORD_BUFFER_END:
