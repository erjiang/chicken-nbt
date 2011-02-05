CFLAGS=
SC=csc

nbt: nbt.ss Makefile
	csc nbt.ss

clean:
	rm -f nbt nbt.c nbt.ss~
