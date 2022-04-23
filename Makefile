BASE.COM: FORTH.ASM DOS.ASM IOWORDS.ASM DICTNRY.ASM
	nasm $< -fbin -o$@

FORTH.COM: BASE.COM CORE.F BUILD.BAT
	dosbox BUILD.BAT

run: BASE.COM
	dosbox $^

size: BASE.COM
	@ls -al $^ | awk '{ print $$5 }'

list-words:
	@rg '^(\s*)DEF(VAR|WORD_|CONST)'
