org 0x07C00
bits 16

%define ENDL 0x0D, 0x0A

;
; FAT12 Header
;

jmp short start
nop

bdb_oem:                     db  'MSWIN4.1'              ; 8 bytes
bdb_bytes_per_sector:        dw  512
bdb_sectors_per_cluster:     db  1                      ; sectors per cluster (always 1)
bdb_reserved_sectors:        dw  1                      ; reserved sectors count
bdb_fat_count:               db  2                      ; number of file allocation tables in the volume 
bdb_dir_entries:             dw  0E0h
bdb_total_sectors32:         dw  2880                   ; total sectors count for FAT12/FAT16 volumes or maximum size = 1.44mb
bdb_media_descriptor_type:   db  0F0h                   ; F0 = 3.5" floppy_disk
bdb_sectors_per_fat:         dw  9
bdb_sectors_per_track:       dw  18
bdb_heads_per_cylinder:      dw  2
bdb_hidden_sectors:          dd  0                       ; hidden sectors - not used by OS/2
bdb_large_sectors_count:     dd  0                       ; total sectors on disk image

# extended boot record
ebr_drive_number:            db  0                       ; 0x00 floppy, 0x80 hdd, useless
                             db  0
ebr_signature:               db  29h
ebr_volume_id:               dq  12h, 34h, 56h, 78h     ; serial number, doesnt matter
ebr_volume_label:            db  "NANOCORE OS"          ; 11 bytes, padded with space
ebr_system_ID:               db  "FAT12   "             ; 8 bytes, padded with spaces

;
; Code Here
;

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

    ;
    ; read something from floppy disk
    ; BIOS should set DL to drive number
    ;
    mov [ebr_drive_number], dl

    mov ax, 1           ; LBA = 1, second sector from disk
    mov cl, 1           ; 1 sector to read
    mov bx, 0x7E00      ; data after bootloader
    call disk_read

    ; print message
    mov si, msg_hello
    call puts

    cli                         ; disable interrupt, CPU cant get out of 'halt' state
    hlt

; 
; Error Handling
; 
floppy_error:
    
    mov si, error_msg
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:

    mov ah, 0 
    int 16h                     ; waiting for keypress
    jmp 0FFFFh:0                ; jump to beginning of BIOS, should reboot?

    hlt

.halt:

    cli                         ; disable interrupt, CPU cant get out of 'halt' state
    hlt                         ; halt CPU


;
; Disk Routines
;

;
; Converts LBA address to CHS address
; Parameters:
;   - ax: LBA adress
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dx [bit 8] : head number
;

lba_to_chs: 

    push ax
    push dx

    xor dx, dx                           ; dx = 0
    div word [bdb_sectors_per_track]     ; ax = LBA / sectors_per_track,
                                         ; dx = LBA % sectors_per_track
    inc dx                               ; dx = (LBA % sectors_per_track + 1) = sector
    mov cx, dx                           ; cx = sector

    xor dx, dx                           ; dx = 0
    div word [bdb_heads]                 ; ax = (LBA / sectors_per_track) / heads = cylinder,
                                         ; dx = (LBA / sectors_per_track) % heads = head
    mov dh, dl                           ; dh = head
    mov ch, al                           ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                            ; cl = cylinder (upper 2 bits)

    pop ax
    mov dl, al                           ; restore dl
    pop ax
    ret

; 
; Disk Reading
; Parameters:
;   - ax: LBA adress
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address for where data should be stored to read
; 

disk_read: 

    push ax                              ; save registers that ill modify
    push bx
    push cx
    push dx
    push di

    push cx                              ; temp save cl
    call lba_to_chs                      ; compute CHS
    pop ax                               ; AL = numb sectors to read

    mov ah, 02h
    mov di, 3                            ; retry count

.retry:

    pusha                                ; save all registers, not sure what is modifying the BIOS
    stc                                  ; setting the carry flag, some BIOS dont set this
    int 13h                              ; disk interrupt (if flag cleared = success)
    jnc .done                            ; jump id carry not set

    ; if flag not cleared = failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    
    ; after all attempts have been made
    jmp floppy_error

.done:

    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax                               ; save registers that were modify
    ret

;
; Reset Disk Controller
; Parameters:
;   - dl: drive number
;
disk_reset:

    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret


msg_helloworld:     db 'Hello World', ENDL, 0
msg_read_fail:      db 'Reading from the disk has failed', ENDL, 0


times 510-($-$$) db 0
dw 0aa55h
