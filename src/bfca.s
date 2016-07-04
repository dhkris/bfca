// bfca 0.2
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
//   The shellscript abfck handles this like:
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
    .string ".arch armv6\n.data\n.balign 4\n.text\n.balign 4\n.global main\n.func main\nmain:\nmov r0, #16384\nmov r1, #4\npush {lr}\nbl calloc\n\pop {lr}\nmov r1, #0\nmov r2, #0\nmov r3, #0"

    // Epilog (register reset, branch out)
    sEpilog:
    .string "mov r0, #0\nbx lr\n\0"

    // Format strings - these ops can be coalesced
    sAdd: .string "add r2, #%d\n\0"                                // Increment current cell
    sSub: .string "sub r2, #%d\n\0"                                // Decrement current cell
    sFwd: .string "strb r2,[r0]\nadd r0,#%d\nldrb r2,[r0]\n\0"     // Increment cell pointer
    sRwd: .string "strb r2,[r0]\nsub r0,#%d\nldrb r2,[r0]\n\0"     // Decrement cell pointer

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

// Register assignment
//  R8: Last character
//  R9: Instruction count
//  R10: Instructions optimized away

// Print prolog
    LDR r0, =sProlog
    PUSH {lr}    
    BL puts
    MOV r8, #0      // File likely doesn`t start with a NUL-byte
    MOV r9, #1      // We can´t have less than 1 of a given instruction...
    B main_loop
    
// For each character input, do
main_loop:

    // if character == EOF then jump to epilog
    BL getchar          
    MOV r7, r0       
    
    // FIRST, we need to evaluate non-coalescable instructions
    // if character == '.' load char output code and output, then jump to loop start
    CMP r8, #46     // '.'
    LDREQ r0, =sOut
    BLEQ puts
    MOVEQ r8, r7
    MOVEQ r9, #1
    BEQ  mlep
    
    // if character == ',' load char input code and output, then jump to loop start
    CMP r8, #44     // ','
    LDREQ r0, =sIn
    BLEQ puts
    BEQ  mlep   

    // if character == '[' load loop begin code and output, then jump to loop start
    CMP r8, #91     // '['
    LDREQ r0, =sLbg
    BLEQ puts
    BEQ  mlep
    
    // if character == ']' load loop end code and output, then jump to loop start
    CMP r8, #93     // ']'
    LDREQ r0, =sLen
    BLEQ puts
    BEQ  mlep     
    
    // THEN, we evaluate coalescable instructions
    // is current input byte identical to the former?
    CMP r7, r8
    ADDEQ r9, #1      // Increment coalesce instruction counter
    BEQ main_loop     // ...and re-iterate the loop 
    
    
    // otherwise, we should check if it`s our initial NUL-byte, because ignoring this
    // means slightly better performance
    CMP r8, #0
    MOVEQ r8, r7
    MOVEQ r9, #1
    BEQ mlep
    
    // if character == '+' load increment code and output, then jump to loop start
    CMP r8, #43 
    LDREQ r0, =sAdd
    MOVEQ r1, r9
    BLEQ printf
    BEQ mlep

    // if character == '-' load decrement code and output, then jump to loop start
    CMP r8, #45    
    LDREQ r0, =sSub
    MOVEQ r1, r9
    BLEQ printf
    BEQ mlep
    
    // if character == '<' load pointer decrement code and output, then jump to loop start
    CMP r8, #60   
    LDREQ r0, =sRwd
    MOVEQ r1, #4
    MUL r1, r9
    BLEQ printf
    BEQ mlep
    
    // if character == '>' load pointer increment code and output, then jump to loop start
    CMP r8, #62     // '>'
    LDREQ r0, =sFwd
    MOVEQ r1, #4
    MUL r1, r9
    BLEQ printf
    BEQ  mlep
    
    CMP r8, #-1         
    BEQ main_end
    
    // and fallback
    B mlep
    
mlep:
    CMP r7, #-1         
    BEQ main_end 
    MOV r9, #1
    MOV r8, r7
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
    