; x86 bootloader to get into 32 bit protected mode
; reference: db is 8 bits, dw is 16 bits, dd 32 bits, dq 64 bits

bits 16     ; Start using 16 bit real address mode
org 0x7c00  ; After reading the magic number, this the address where code begins executing

boot:       ; execution begins here
    jmp init_32bits

gdt:                ; start of the global descriptor table
.null_descriptor:   ; must start with a null descriptor
    dq 0x0
.code_segment:      ; we want a code segment that can access the entire 4Gb
    dw 0xffff       ; 15 bits defining segment limit
    dw 0x0          ; lower 15 bits of base 
    db 0x0          ; 16-23rd bits of base
    db 0x9a			; 9 defines present and code/data segment, a defines executable and is readable
	db 0b11001111	; high 4 bits is the flag defining 4kb pages and protected mode, low 4 bits is bits 16-19 of limit
	db 0x0			; base 24-31 bits

.data_segment:	    ; same for data segment
	dw 0xffff		; 15 bits defining segment limit
	dw 0x0			; lower 15 bits of base 
	db 0x0			; 16-23rd bits of base
	db 0x92			; 9 defines present and code/data segment, a segment is writable
	db 0b11001111	; high 4 bits is the flag defining 4kb pages and protected mode, low 4 bits is bits 16-19 of limit
	db 0x0			; base 24-31 bits
.gdt_end:

gdtr:
    dw gdt.gdt_end - gdt ; size of gdt
    dd gdt               ; location of gdt

CODE_SEG equ gdt.code_segment - gdt ; get the segment number for the code segment
DATA_SEG equ gdt.data_segment - gdt ; segment number for the data segment

print_BIOS:             ; print using bios - only accessible in 16 bit real mode and assumes memory address of string to be printed is in si
    mov ah, 14          ; set higher bits of a register to print character mode
    mov bh, 0
.loop:
    lodsb               ; load next character into al
    cmp al, 0           ; once the null byte is reached, we know we have reached the end of the string
    je .done
    int 0x10            ; interrupt to print to the screen
    jmp .loop
.done:
    ret
    
init_32bits:   ; initialize the GDT
    mov ax, 0
    mov sp, 0xFFFC ; initialize the stack pointer to highest possible address
    mov ss, ax     ; set stack segment to 0
    mov ds, ax     ; set data segment to 0
    mov es, ax     ; set destination segment to 0
    mov fs, ax     ; fs and gs registers have no processor purpose, but can be used later by OS
    mov gs, ax

    ; set vga to be normal mode
    mov ax, 0x3
    int 0x10

    call read_sector_from_disk
    
    cli               ; Clear interrupts to prevent unintended behavior
    lgdt [gdtr]       ; load address of gtd descriptor structure into gdtr register
    mov eax, cr0      ; get value of cr0 register
    or eax, 0x1       ; enable real mode
    mov cr0, eax      ; update cr0 register
    in al, 0x92       ; perform fast a20 gate
    or al, 2
    out 0x92, al
    sti               ; restore interrupts as we are in 32 bit protected mode now
    jmp CODE_SEG:b32  ; jump to our 32 bit code
 
read_sector_from_disk:
	mov ah, 0x02      ; instruct bios to read from disk
	mov al, 0x5       ; read 2 sectors from disk
	mov ch, 0x00      ; track/cylinder number
    mov cl, 0x2       ; sector number (first sector is sector 1)
    mov dh, 0x00      ; head number 0
    xor bx, bx        ; clear out es
    mov es, bx
    mov bx, 7e00h     ; load the code 512 bytes past 0x7c00h
	int 0x13          ; read sectors
	ret

bits 32 ; code is now 32 bit

VIDEO_MEMORY equ 0xb8000     ; address of the start of video memory
WHITE_TEXT equ 0x0f          ; white text color with no background color
NOTRE_DAME_TEXT equ 0x1E     ; yellow text on blue background


print32:
    mov edx, VIDEO_MEMORY    ; get the address of video memory
.loop:
    mov al, [ebx]            ; read the current character
    mov ah, NOTRE_DAME_TEXT  ; add the text color byte
    cmp al, 0                ; check to see if reached null and are done
    je .done
    mov [edx], ax            ; move our ascii text and color code into video memory
    add ebx, 1               ; increment to the next character in the string
    add edx, 2               ; increment two bytes in video memory (one for color code, one for character)
    jmp .loop
.done:
    ret

b32:
    mov ax, DATA_SEG        ; set our current segment as the data segment
    mov ds, ax              ; update data segment
    mov es, ax              ; and destination segment
    mov fs, ax              ; unused segment (for now)
    mov gs, ax              ; unused
    mov ss, ax              ; update stack segment

    mov ebp, 0x2000         ; set our stack to start at this value
    mov esp, ebp

    call test_A20           ; test to make sure the A20 line was set properly

    jmp kernelstart

; Code taken from https://wiki.osdev.org/A20_Line
; Check A20 line
; Returns to caller if A20 gate is cleared.
; Continues to A20_on if A20 line is set.
; Written by Elad Ashkcenazi 
 
test_A20:   
    pushad
    mov edi,0x112345  ;odd megabyte address.
    mov esi,0x012345  ;even megabyte address.
    mov [esi],esi     ;making sure that both addresses contain diffrent values.
    mov [edi],edi     ;(if A20 line is cleared the two pointers would point to the address 0x012345 that would contain 0x112345 (edi)) 
    cmpsd             ;compare addresses to see if the're equivalent.
    popad
    je A20_off        ;if equivalent , A20 line is not set.
    ret               ;if not equivalent , the A20 line is set.
A20_off:
    mov ebx, A20error
    call print32
    cli 
    hlt

helloboot db "helloboot", 0
A20error db "Unable to enable A20 line", 0

times 510-($-$$) db 0 ; Add any additional zeroes to make 510 bytes in total
dw 0xAA55 ; write the magic number 0x55aa at the end of the first 510 bytes

%include "kernal.asm"