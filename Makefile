CFLAGS=
SC=csc

leveldat: leveldat.ss Makefile
	csc leveldat.ss

clean:
	rm -f leveldat leveldat.c leveldat.ss~
