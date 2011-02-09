CFLAGS=
SC=csc

default: nbt.so displaynbt

nbt.so: nbt.ss Makefile
	csc -j nbt -s nbt.ss

displaynbt: nbt.so displaynbt.ss
	csc displaynbt.ss

clean:
	rm -f nbt nbt.so nbt.c nbt.ss~
	rm -f displaynbt
