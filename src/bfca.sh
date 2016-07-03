#!/bin/bash
OUTPUTFILE=$2
if [[ -z $2 ]]; then
	OUTPUTFILE="bf.out"
fi
echo "Compiling to $OUTPUTFILE..."
cat $1 | bfca.codegen > __BFK_TEMP.s
as __BFK_TEMP.s -o __BFK_TEMP.o
cc __BFK_TEMP.o -o $OUTPUTFILE
rm -f __BFK_TEMP.*
