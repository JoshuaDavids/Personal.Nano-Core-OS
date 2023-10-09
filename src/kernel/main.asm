org 0x07C00
bits 16

%define ENDL 0x0D, 0x0A

start:
    jmp main

;
; Prints a string to screen
; Params:
;   - ds:si points to string
;
puts: 
    ; save registers we will directly modify
    push si
    push ax

.loop:
    lodsb           ; loads next character in al
    or al, al       ; verify if next character is null
    js .done
    jmp .loop

    mov ah, 0x0e
    mov bh, 0
    int 0x10


.done: 
    pop ax
    pop si
    ret

main: 

    ; setup data segements
    mov ax, 0           ; cant write to ds/es directly
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax          ; set the stack segment register (ss)
    mov sp, 0x7C00

    ; print message
    mov si, msg_hello
    call puts

    hlt

.halt:
    jmp .halt


msg_helloworld: 'Hello World', ENDL, 0


times 510-($-$$) db 0
dw 0aa55h
