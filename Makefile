all:
	as src/bfca.s -o src/__build__bfca.o
	cc src/__build__bfca.o -o src/bfca.codegen

install:
	cp src/bfca.codegen /usr/bin/bfca.codegen
	cp src/bfca.sh /usr/bin/bfca
	chmod a+x /usr/bin/bfca.codegen
	chmod a+x /usr/bin/bfca

clean:
	rm src/__build__bfca.o
	rm src/bfca.codegen
