org 0x7c00
bits 16
;;macros
%define ENDL 0x0D,0x0A  ;ENDL='\n'
start:
    jmp main

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


main:
    ;setup data segments
    mov ax,0
    mov dx,ax
    mov es,ax

    ;setup stack
    mov ss,ax
    mov sp,0x7c00

    mov si,msg_hello
    call puts
    
    hlt 
.halt:
    jmp .halt


msg_hello: db 'Hello world!', ENDL, 0

times 510 -($-$$ ) db 0
dw 0AA55h
