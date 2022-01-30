;;; Assembly definitions of built-in Forth words
;;; Assume this is included after all the relevant macros


;;; INPUT & OUTPUT ROUTINES ;;;
	;; Read a key from the input. If STDIN is blank wait for a key
	;; press.
	;;
	;; TODO: Keep an internal buffer until RETURN is pressed, allow
	;; some line editing.
	;;
	;; Actually, that could be implemented in Forth for simplicity.
	DEFWORD_RAW KEY, 'KEY'
	CALL READ_KEY
	PUSH AX
	NEXT
	
	;; This routine returns the key in AL, but Forth wants it on the
	;; stack, so we have a helper function.
READ_KEY:
	;; Check if line buffer is empty
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


	;; ( flags *start len -- handle )
	DEFWORD_RAW OPEN_FILE_NAMED, 'OPEN-FILE-NAMED'
	POP CX						; Length
	POP BX						; Start
	MOV DX, BX
	ADD BX, CX
	MOV BYTE [BX], 0
	POP CX						; Flags
	CREATF

	MOV AX, CX					; Flags
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
