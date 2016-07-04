#!/bin/bash
OUTPUTFILE=$2
if [[ -z $2 ]]; then
	OUTPUTFILE="bf.out"
fi
echo "Compiling $1"
cat $1 | bfca.codegen > __BFK_TEMP.s

echo "Assembling and linking $OUTPUTFILE"
as __BFK_TEMP.s -o __BFK_TEMP.o
cc -s __BFK_TEMP.o -o $OUTPUTFILE
rm -f __BFK_TEMP.*
echo "Done."
