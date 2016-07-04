BFCA
======
Brainf**k Compiler for ARM
---------------------------

**BFCA** (pronounced "Buffka") is a native-code Brainf*ck compiler for the ARM architecture, and is written in ARM assembly itself.

### Author, copyright & license
BFCA is written by **David H. Christensen**, a mobile device development enthusiast (and thus, lover of all things ARM) and Mobile Solutions Architect at DIS/PLAY A/S, one of the leading digital agencies in Denmark.

BFCA is licensed under the 3-clause BSD license.

### Invocation
The most convenient way to use the BFCA compiler is to use the `bfca` shell script,

**`$`** `bfca input.bf`

The compiled and linked binary will be immediately executable as `bf.out`.
Alternatively, you can use the `bfca.codegen` binary, which accepts input from `stdin` and prints the output assembly code to `stdout`. Additionally, you will have to assemble the file, and link the object binary with your platform's C library, which is most easily done with `cc`:

**`$`** `cat input.bf | bfca.codegen > output.s`  
**`$`** `as output.s -o output.o`  
**`$`** `cc output.o -o output`  
**`$`** `./output`

Using `bfca.codegen`, you are also able to inspect the assembler output.

### Optimization
BFCA is an optimizing compiler. The following optimizations are used:

* Multiple identical instructions are coalesced into a single machine instruction. For instance, the sequence `++++` emits a single `ADD r2, #4` instruction instead of four `ADD r2, #1` instructions. This applies to:
   * +
   * -
   * >
   * <
* Cells are only read from and written back to memory when the cell pointer moves. Therefore, only > and < instructions actually cause a write to and read from memory. Inbetween these, the value is held in the r2 register.
* Cells are actually 4 bytes wide, since these aligned reads are faster than unaligned reads.

### Register allocation in output code
* **r0**: External function call parameter/return value; pointer to current cell memory address
* **r1**: External function call parameter
* **r2**: Accumulator, receiving value of the new cell on cell pointer change, as well as holding intermediate results until the next cell change
* **r4**, **r5**, **r6**: Buffer registers to hold values of **r0** and **r2** during external function calls without memory accesses
* **r8**: Loop intermediate register. Receives the instruction address of the loop start at the `]` instruction from the stack. This address - 8 *(the loop start instruction encodes to 8 bytes)* is equivalent to the start of the current loop.

### Looping
Loops work fully as expected (i.e. they can be nested). Loops are implemented using stack memory. The following happens:

**`[`**: Push program counter to stack  
**`]`**: Pop into `r8`, subtract 8 from `r8`, then move contents of `r8` into `pc`, thus returning to the `[` instruction.

Thus, nested loops are eminently possible. The stack on most Linux distributions is 8 MB large, and a single loop iteration typically takes up 4 *bytes* (on 32-bit Linux, including the Raspberry Pi 3); that's a grand total of more than a million loops deep. In other words, effectively infinite loop nesting.

### Binary size
The typical BFCA output binary isn't very big at all. The *"Hello, World"* example on Wikipedia takes up a grand total of ~6 kilobytes.

This is expected to be even less in BFCA 0.2 due to instruction coalescing; the Hello World application code will take up around 50% less due to adjacent identical instructions being merged.