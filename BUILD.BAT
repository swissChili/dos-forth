@echo off
echo [ ASM ] Assembling BASE.COM
NASM FORTH.ASM -o BASE.COM -fbin
echo [FORTH] Bootstrapping CORE.COM
BASE < CORE.F
echo [ OK  ] CORE.COM
