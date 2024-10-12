bits 16

section _TEXT class=CODE

global _x86_Video_WriteCharTeletype 
_x86_Video_WriteCharTeletype:

    push bp
    mov bp,sp

    push bx

    mov ah,0Eh
    mov al,[bp+4]   ;first argument - char
    mov bh,[bp+6]   ;second arguement - page

    ;int 10h ah=0Eh
    ;print char to screen
    int 10h

    pop bx
    
    mov sp,bp
    pop bp
    ret