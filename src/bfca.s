// bfca 0.1
// Brainfuck compiler for ARM
//
// Copyright © David H. Christensen
//        me@davidh.info 
// Licensed under the BSD license.
//
// DESCRIPTION:
//   Gets input via stdin, outputs via stdout
// USAGE:
//   cat "programfile" | bfca.codegen > outputfile.s; as outputfile.s -o outputfile.o; cc outputfile.o -o outputfile; ./outputfile
//   The shellscript bfca handles this like:
//     bfca program.bf binary
//     ./binary
//
//   Binaries require linking with a C library due to the usage of four library functions, namely
//     calloc, putchar, getchar, free
//
// INFO:
//   Written in ARM assembly (uses GNU assembler)
//   Works with all ARMv6+ devices, including all Raspberry Pi models.
//
// PLAN:
//   Not yet optimizing, but 0.2 will "unroll" subsequent identical instructions
//   such that ++++ is coalesced to a single +4 addition instruction.

.arch armv6
.data
.balign 4

// FUNCTIONAL COMPONENTS
    // Prologue (32 kB memory allocation, register setup...)
    sProlog: 
    .string ".arch armv6\n.data\n.balign 4\n.text\n.balign 4\n.global main\n.func main\nmain:\nmov r0, #8192\nmov r1, #4\npush {lr}\nbl calloc\n\pop {lr}\nmov r1, #0\nmov r2, #0\nmov r3, #0"

    // Epilog (register reset, branch out)
    sEpilog:
    .string "mov r0, #0\nbx lr\n\0"


    sAdd: .string "add r2, #1\0"                                // Increment current cell
    sSub: .string "sub r2, #1\0"                                // Decrement current cell
    sFwd: .string "strb r2,[r0]\nadd r0,#4\nldrb r2,[r0]\0"     // Increment cell pointer
    sRwd: .string "strb r2,[r0]\nsub r0,#4\nldrb r2,[r0]\0"     // Decrement cell pointer

    // Output character
    sOut: .string "push {lr}\nmov r6, r0\nmov r4, r2\nmov r0, r2\nbl putchar\nmov r0, r6\nmov r2, r4\npop {lr}\0"
              
    // Input character
    sIn:  .string "push {lr}\nmov r5, r0\nbl getchar\nmov r2, r0\nmov r0, r5\npop {lr}\0",
         
    // Begin loop     
    sLbg: .string  "push {pc}\0"

    // End loop if *cell == 0
    sLen: .string  "cmp r2, #0\npopne {r8}\nsubne r8, #8\nmovne pc, r8\npopeq {r8}\n\0"
// ----------------------


.text

.balign 4
.global main
.func main
main:

// Print prolog
    LDR r0, =sProlog
    PUSH {lr}    
    BL puts
    B main_loop
    
// For each character input, do
main_loop:

    // if character == EOF then jump to epilog
    BL getchar          
    CMP r0, #-1         
    MOV r1, r0
    BEQ main_end        
    
    // if character == '+' load increment code and output, then jump to loop start
    CMP r1, #43 
    LDREQ r0, =sAdd
    BLEQ puts
    BEQ  main_loop
    
    // if character == '-' load decrement code and output, then jump to loop start
    CMP r1, #45    
    LDREQ r0, =sSub
    BLEQ puts
    BEQ  main_loop
    
    // if character == '<' load pointer decrement code and output, then jump to loop start
    CMP r1, #60   
    LDREQ r0, =sRwd
    BLEQ puts
    BEQ  main_loop
    
    // if character == '>' load pointer increment code and output, then jump to loop start
    CMP r1, #62     // '>'
    LDREQ r0, =sFwd
    BLEQ puts
    BEQ  main_loop
    
    // if character == '.' load char output code and output, then jump to loop start
    CMP r1, #46     // '.'
    LDREQ r0, =sOut
    BLEQ puts
    BEQ  main_loop
    
    // if character == ',' load char input code and output, then jump to loop start
    CMP r1, #44     // ','
    LDREQ r0, =sIn
    BLEQ puts
    BEQ  main_loop   

    // if character == '[' load loop begin code and output, then jump to loop start
    CMP r1, #91     // '['
    LDREQ r0, =sLbg
    BLEQ puts
    BEQ  main_loop
    
    // if character == ']' load loop end code and output, then jump to loop start
    CMP r1, #93     // ']'
    LDREQ r0, =sLen
    BLEQ puts
    BEQ  main_loop 
    
    // undefined character means jump to loop start
    B main_loop   


// Epilog
main_end:

    // Load epilog string, print it to output
    LDR r0, =sEpilog
    BL puts
    
    // Load our return address so we don`t segfault
    POP {lr}
    
    // Clear parameter and return registers
    MOV r0, #0
    MOV r1, #1
    MOV r2, #0
    MOV r3, #0
    
    // return 0;
    BX lr

.endfunc
    
