// bfca 0.2.1
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
// HISTORY
// 0.2.1:
//  * Added library support: bfca can now generate code that can be integrated into
//    programs written in other langauges (for instance, C.). To do this,
//    use
//   
//      bfca source.bf outputexecutable "function_name"
//
//    this will generate a C function of the form
//
//       int* function_name()
//
//    In later versions, it should be possible to pass in a pointer to allocated memory
//    to allow input data as the original state of the memory cells.
//
// 0.2:
//  * Compiler is now optimizing (coalesces identical +-<> operations to single machine instructions)
//
// 0.1: 
//  * Initial release

.arch armv6
.data
.balign 4

// FUNCTIONAL COMPONENTS
    // Prologue (16 kB memory allocation, register setup...)
    sProlog: 
    .string ".arch armv6
.data
.balign 4
.text
.balign 4
.global main
.func main
main:
mov r0, #16384
mov r10, lr
mov r1, #4
bl calloc
mov r1, #0
mov r2, #0
mov r3, #0"

    // Prologue for non-main function output
    sPrologNonMain: .string ".arch armv6\n.data\n.balign 4\n.text\n.balign 4\n.global __replace__\n.func __replace__
__replace__:\npush {r4-r10}\nmov r0, #16384\nmov r10, lr\nmov r1, #4\nbl calloc\nmov r1, #0\nmov r2, #0\nmov r3, #0"

    // Epilog (register reset, branch out)
    sEpilog: .string "mov r0, #0\nmov lr, r10\nbx lr\n\0"
    
    sEpilogNonMain: .string "mov r0, #0\nmov lr, r10\npop {r4-r10}\nbx lr\n.endfunc\n\0"    

    // Format strings - these ops can be coalesced
    sAdd: .string "add r2, #%d\n\0"                                // Increment current cell
    sSub: .string "sub r2, #%d\n\0"                                // Decrement current cell
    sFwd: .string "strb r2,[r0]\nadd r0,#%d\nldrb r2,[r0]\n\0"     // Increment cell pointer
    sRwd: .string "strb r2,[r0]\nsub r0,#%d\nldrb r2,[r0]\n\0"     // Decrement cell pointer

    // Output character
    sOut: .string "mov r6, r0\nmov r4, r2\nmov r0, r2\nbl putchar\nmov r0, r6\nmov r2, r4\0"
              
    // Input character
    sIn:  .string "mov r5, r0\nbl getchar\nmov r2, r0\nmov r0, r5\0",
         
    // Begin loop     
    sLbg: .string  "push {pc}\0"

    // End loop if *cell == 0
    sLen: .string  "cmp r2, #0\npopne {r8}\nsubne r8, #8\nmovne pc, r8\npopeq {r8}\n\0"
// ----------------------

// DIAGNOSTICS
    sDiagMemAddr: .string "Address: %x\n\0"
    sTotalInstructionCount:  .string "Processed %d operations\n\0"
    sOptimizedCount: .string "Optimizations removed %d operations\n\0"
    sOutputOptimizCount: .string "Output %d instructions to disk\n\0"



.text

.balign 4
.global main
.func main
main:

    PUSH {r4-r10,r12}
// Check for cmdline arg (we should export as function...)
    CMP r0, #2 
    MOVEQ r12, #1 
    BEQ export_as_function

// Register assignment
//  R8: Last character
//  R9: Instruction count
//  R10: Total instruction count
//  R4:  Total optimization count

// Print prolog
    LDR r0, =sProlog
    PUSH {lr}    
    BL puts
    B main_start_loop
    
// BFCA can also compile to an object. This allows you to incorporate the generated
// code in a C program (for instance), or to build a shared library.
// For this purpose, it is necessary to output a different method name than main.
// Also, since the function will not be a standalone program, it is necessary to save
// the scratch registers we use.
export_as_function:
    LDR r0, =sPrologNonMain
    PUSH {lr}    
    BL puts
    B main_start_loop

// Setup scratch registers and start the main loop
main_start_loop:
    MOV r4, #0
    MOV r10, #0
    MOV r8, #0      // File likely doesn`t start with a NUL-byte
    MOV r9, #1      // We can´t have less than 1 of a given instruction...
    B main_loop

    
// MAIN LOOP    
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
    ADDEQ r10, #1
    BEQ mlep    // its faster to include it here, since we won`t have to do the remaining
                // comparisons
        
    // if buffer character == ',' load char input code and output, then jump to loop start
    CMP r8, #44     // ','
    LDREQ r0, =sIn
    BLEQ puts
    ADDEQ r10, #1
    BEQ mlep  
    
    // if buffer character == '[' load loop begin code and output, then jump to loop start
    CMP r8, #91     // '['
    LDREQ r0, =sLbg
    BLEQ puts
    ADDEQ r10, #1
    BEQ mlep
        
    // if buffer character == ']' load loop end code and output, then jump to loop start
    CMP r8, #93     // ']'
    LDREQ r0, =sLen
    BLEQ puts
    ADDEQ r10, #1
    BEQ mlep 
        
    // THEN, we evaluate coalescable instructions
    // is current input byte identical to the former?
    CMP r7, r8
    ADDEQ r4, #1
    ADDEQ r9, #1      // Increment coalescing instruction instance count
    ADDEQ r10, #1
    BEQ main_loop     // ...and re-iterate the loop 
    
    
    // otherwise, we should check if it`s our initial NUL-byte, because ignoring this
    // means slightly better performance
    CMP r8, #0
    MOVEQ r8, r7
    MOVEQ r9, #1
    ADDEQ r10, #1
    BEQ mlep
        
    // if buffer character == '+' load increment code with accumulated count and output
    CMP r8, #43 
    LDREQ r0, =sAdd
    MOVEQ r1, r9
    BLEQ printf
    ADDEQ r10, #1
    BEQ mlep
    
    // if character == '-' load decrement code with accumulated count and output
    CMP r8, #45    
    LDREQ r0, =sSub
    MOVEQ r1, r9
    BLEQ printf
    ADDEQ r10, #1
    BEQ mlep
    
    // if character == '<' load pointer decrement code with accumulated count and output
    CMP r8, #60   
    LDREQ r0, =sRwd
    MOVEQ r1, #4
    MUL r1, r9
    BLEQ printf
    ADDEQ r10, #1
    BEQ mlep
    
    // if character == '>' load pointer increment code with accumulated count and output
    CMP r8, #62     // '>'
    LDREQ r0, =sFwd
    MOVEQ r1, #4
    MULEQ r1, r9
    BLEQ printf
    ADDEQ r10, #1
    BEQ mlep
    
    CMP r8, #-1         
    BEQ main_end
    
    // and fallback
    B mlep
    
// Main Loop End Pass
mlep:
    CMP r7, #-1         
    BEQ main_end 
    MOV r9, #1
    MOV r8, r7
    B main_loop   

// Epilog
main_end:

    // Load epilog string, print it to output. If a cmdline arg was passed, output the function epilog.
    CMP r12, #1
    LDREQ r0, =sEpilogNonMain
    LDRNE r0, =sEpilog
    BL puts
    
    // Load our return address so we don`t segfault
    POP {lr}

    // ..and our scratch registers
    POP {r4-r10,r12}
    
    // Clear parameter and return registers
    MOV r0, #0
    MOV r1, #1
    MOV r2, #0
    MOV r3, #0
    
    // return 0;
    BX lr

.endfunc
    