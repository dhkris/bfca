.eabi_attribute 12, 3
.arch armv8-a
.fpu neon-fp-armv8
.data
.balign 4

sProlog: 
.string ".arch armv6\n.data\n.balign 4\n.text\n.balign 4\n.global main\n.func main\nmain:\nmov r0, #8192\nmov r1, #4\npush {lr}\nbl calloc\n\pop {lr}\nmov r1, #0\nmov r2, #0\nmov r3, #0"

sEpilog:
.string "mov r0, #0\nbx lr\n\0"

sAdd: .string "add r2, #1\0"                                // +
sSub: .string "sub r2, #1\0"                                // -
sFwd: .string "strb r2,[r0]\nadd r0,#4\nldrb r2,[r0]\0"     // >
sRwd: .string "strb r2,[r0]\nsub r0,#4\nldrb r2,[r0]\0"     // <

sOut: .string "push {lr}\nmov r6, r0\nmov r4, r2\nmov r0, r2\nbl putchar\nmov r0, r6\nmov r2, r4\npop {lr}\0"
              
sIn:  .string "push {lr}\nmov r5, r0\nbl getchar\nmov r2, r0\nmov r0, r5\nstrb r2, [r0]\npop {lr}\0",
              
sLbg: .string  "push {pc}\0"
sLen: .string  "cmp r2, #0\npopne {r8}\nsubne r8, #8\nmovne pc, r8\npopeq {r8}\n\0"

.text

.balign 4
.global main
.func main
main:
    LDR r0, =sProlog
    PUSH {lr}    
    BL puts
    B main_loop
    
main_loop:
    BL getchar          // r0 = getchar();
    CMP r0, #-1         // EOF?
    MOV r1, r0
    BEQ main_end        // Jump to prologue
    
    CMP r1, #43    // r0 == '+'
    LDREQ r0, =sAdd
    BLEQ puts
    BEQ  main_loop
    
    CMP r1, #45    // r0 == '-'
    LDREQ r0, =sSub
    BLEQ puts
    BEQ  main_loop
    
    CMP r1, #60    // r0 == '<'
    LDREQ r0, =sRwd
    BLEQ puts
    BEQ  main_loop
    
    CMP r1, #62     // '>'
    LDREQ r0, =sFwd
    BLEQ puts
    BEQ  main_loop
    
    CMP r1, #46     // '.'
    LDREQ r0, =sOut
    BLEQ puts
    BEQ  main_loop
    
    CMP r1, #44     // ','
    LDREQ r0, =sIn
    BLEQ puts
    BEQ  main_loop   

    CMP r1, #91     // '['
    LDREQ r0, =sLbg
    BLEQ puts
    BEQ  main_loop
    
    CMP r1, #93     // ']'
    LDREQ r0, =sLen
    BLEQ puts
    BEQ  main_loop 
    
    B main_loop   

main_end:
    LDR r0, =sEpilog
    BL puts
    POP {lr}
    MOV r0, #0
    MOV r1, #1
    MOV r2, #0
    MOV r3, #0
    BX lr

.endfunc
    