org 0x0
bits 16
;;macros
%define ENDL 0x0D,0x0A  ;ENDL='\n'
start:

    mov si, msg_hello
    call puts 

.halt
    cli
    hlt
;
;Prints Strings to the Screen
;
; Parameters
;   DS:SI: points to the string.Must be Null turmintated
puts:
    ;save registers
    push si 
    push ax
    push bx

.loop:
    lodsb 
    or al,al    ;check if null
    jz .done

    ;load INT 10h
    ;write AL to screen
    mov ah,0x0e
    mov bh,0 
    int 0x10

    jmp .loop

.done:
    pop bx
    pop ax
    pop si
    ret



msg_hello: db 'Hello world!', ENDL, 0
