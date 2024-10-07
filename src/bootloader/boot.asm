org 0x7c00
bits 16
;;macros
%define ENDL 0x0D,0x0A  ;ENDL='\n'

;
; FAT12 header
; 
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
                            db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value doesn't matter
ebr_volume_label:           db 'TIMOR  MYOS'        ; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes

;
; Code goes here
;

start:
    ;setup data segments
    mov ax,0
    mov ds,ax
    mov es,ax

    ;setup stack
    mov ss,ax
    mov sp,0x7c00


    ; some BIOSes might start us at 07C0:0000 instead of 0000:7C00, make sure we are in the
    ; expected location
    push es
    push word .after
    retf
  ;;makeing sure Bios start     
    push es
    push word .after
    retf

.after:

     ; read something from floppy disk
    ; BIOS should set DL to drive number
    mov [ebr_drive_number], dl

    ; show loading message
    mov si, msg_loading
    call puts
    
    ; read drive parameters (sectors per track and head count),
    ; instead of relying on data on formatted disk
    push es
    mov ah, 08h
    int 13h
    ;;int 13h,ah=08
    ;CF will set on Error
    ;CX[5:0]= number of sectors per track
    ;CX[6:15]= number of cylinders

    ;Error in reading disk   
    jc floppy_error
    pop es

    ;sector count
    and cl, 0x3F                        ; remove top 2 bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx     

    ;head count
    inc dh
    mov [bdb_heads], dh 

    ; compute LBA of root directory = reserved + fats * sectors_per_fat
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh,bh
    mul bl                              ; ax = (fats * sectors_per_fat)
    add ax, [bdb_reserved_sectors]      ; ax = LBA of root directory
    push ax

    ; compute size of root directory = (32 * number_of_entries) / bytes_per_sector
    mov ax, [bdb_dir_entries_count]
    shl ax, 5
    xor dx,dx
    div word [bdb_bytes_per_sector] ; number of sectors we need to read
    
    ;check if sector paritally filled(ax)
    test dx, dx     
    jz .root_dir_after
    inc ax

;read root diretory
.root_dir_after:

    mov cl,al                   ;cl = number of sectors to read
    pop ax                      ;ax = LBA of root directory
    mov dl, [ebr_drive_number]  ;dl = driver number
    mov bx, buffer              ;es:bx=buffer that loaded into
    call disk_read

    ;search for kernel.bin
    xor bx, bx
    mov di, buffer 

;searching through all root directory
.search_kernel:   
    
    mov si, file_kernel_bin
    mov cx, 11
    push di
    repe cmpsb
    pop di
    je .found_kernel

    ;if dont match
    add di, 32      ;moving to next Directory entry
    inc bx
    cmp bx,[bdb_dir_entries_count]
    jl .search_kernel

    ;kernel not found
    jmp kernel_not_found_error

.found_kernel:

    ;di should have the address to the entry
    mov ax, [di+26]
    mov [kernel_cluster], ax

    mov ax, [bdb_reserved_sectors]
    mov bx, buffer 
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    ;read kernel and process FAT chain
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET


.load_kernel_loop:

    ;read next cluster
    mov ax, [kernel_cluster]

    add ax,31                   ;first cluster+=start_sector
                                ;start_sector=reserved+fats+root_dir=1+18+134=33

    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]

    ;compute location of next cluster
    mov ax, [kernel_cluster]
    mov cx,3
    mul cx
    mov cx, 2
    div cx          ;ax = index of entry in FAT, dx = cluster mod 2

    mov si, buffer
    add si, ax
    mov ax, [ds:si]                 ;read entry from FAT table at index ax

    or dx, dx
    jz .even


.odd:
    shr ax, 4
    jmp .next_cluster_after
.even:
    and ax,0x0FFF

.next_cluster_after:
    cmp ax,0x0FF8
    jae .read_finish

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.read_finish:
    ;jump back to kernel
    mov dl, [ebr_drive_number]  ;boot device in dl

    mov ax, KERNEL_LOAD_SEGMENT
    mov ds, ax
    mov es, ax
    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    jmp wait_key_and_reboot
    
    cli 
    hlt
;
;Error handaling
;

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_kernel_not_found
    call puts
    jmp wait_key_and_reboot
wait_key_and_reboot:
    mov ah, 0
    int 16              ;wait keypress
    jmp 0FFFFh:0        ;jump beginning of BIOS, basiclly reboot

.halt:
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


;
;
;

;
;Disk managment
;

;
;converts an LBA address to a CHS address
;Parameters:
;   ax: LBA address
;Returns:
;   cx [bits 0-5]: sector number
;   cx [bits 5-15]: cylinder
;   dh: head
;
lba_to_chs:
    push ax
    push dx

    xor dx,dx
    div word [bdb_sectors_per_track]    ;ax=LBA / SectorsPerTrack
                                        ;dx= LBA % SectorsPerTrack

    inc dx          
    mov cx,dx                           ;cx=sector=(LBA%SectorsPerTrack+1)

    xor dx,dx
    div word [bdb_heads]                ;ax=(LBA/ SectorsPerTrack) / Heads =cyliner
                                        ;dx=(LBA /SectorsPerTrack) % Headds= head
    mov dh, dl                          ;dh= head
    mov ch, al                          ;ch=cylinder
    shl ah,6
    or cl, ah                           ;puts 2 bits of cylnder in CL

    pop ax
    mov dl,al                            ;restore DL 
    pop ax
    ret    

;
; Reads sectors from a disk
; Parameters
;   ax: LBA address
;   cl: number of sectors to read
;   dl: drive number
;   es:bs: memory addresss where to store read data
;
disk_read:
    push ax
    push bx
    push cx
    push dx
    push di
    
    push cx             ;saving CL(number of sectors to read)
    call lba_to_chs
    pop ax              ;al= number of sectors to read

    mov ah,02h
    mov di, 3

.retry:
    pusha               ;saves register before calling bios
    stc                 ;set carry flag=1
    int 13h             ;int 13=Read Disk Sector
    jnc .done           ;jump is carry not set=success

    ;read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry          ;we are going to try 3 times
;if we failed 3 times
.fail:
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret


;
; Resets disk controller
; Parameters:
;   dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_loading:    db 'Loading..', ENDL,0
msg_read_failed:    db 'Read disk failed!', ENDL,0
msg_kernel_not_found:   db 'KERNEL.BIN file not found!', ENDL,0
file_kernel_bin:    db 'KERNEL  BIN'
kernel_cluster: dw 0

KERNEL_LOAD_SEGMENT equ 0x2000
KERNEL_LOAD_OFFSET equ 0
times 510 -($-$$ ) db 0
dw 0AA55h

buffer:
