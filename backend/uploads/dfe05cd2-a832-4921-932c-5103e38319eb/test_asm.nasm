section .text
global _start

_start:
    ; Write "Hello, World!" to stdout
    mov rax, 1           ; syscall number for sys_write
    mov rdi, 1           ; file descriptor 1 is stdout
    mov rsi, hello       ; pointer to message
    mov rdx, hello_len   ; message length
    syscall

    ; Exit with status code 0
    mov rax, 60          ; syscall number for sys_exit
    xor rdi, rdi         ; status code 0
    syscall

section .data
    hello: db "Hello, World!", 10
    hello_len: equ $ - hello 