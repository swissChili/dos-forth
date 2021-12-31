FORTH.COM: FORTH.ASM DOS.ASM IOWORDS.ASM DICTNRY.ASM
	nasm $< -fbin -o$@

run: FORTH.COM
	dosbox $^
