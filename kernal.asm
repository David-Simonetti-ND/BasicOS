PIC1_COMMAND       equ 0x20      ; command and data ports for the PIC1 and PIC2 chips
PIC1_DATA          equ 0x21
PIC2_COMMAND       equ 0xA0
PIC2_DATA          equ 0xA1

idt:
.timer_interrupt:
    dw 0                             ; we load the offset for the interrupt handler down below
    dw CODE_SEG                      ; segment where interrupt handler lives
    db 0x0                           ; reserved 
    db 0x8E                          ; set present, ring, and 32 bit interrupt
    dw 0x0                           ; upper bits of offset not used
    times 255 * 8 db 0
.idt_end:
idtr:
    dw idt.idt_end - idt - 1 ; size of idt
    dd idt               ; location of idt

generic_interrupt_handler:    ; interrupt handler just prints out debug message
    mov ebx, helloboot
    call print32
    iret   

program_pic:                    ; reprogram PIC to change overlapping interrupts 
    mov al, 0x11                ; 0x11 is the signal to start the initialization sequence
    out PIC1_COMMAND, al        ; send it to PIC1
    nop
    out PIC2_COMMAND,al         ; and send it to PIC2
    nop
    mov al,0x20                 ; set PIC1's starting interrupt to be 0x20 (32)
    out PIC1_DATA,al
    nop
    mov al,0x28                 ; set PIC1's starting interrupt to be 0x28 (40)
    out PIC2_DATA,al
    nop
    mov al,0x04                 ; Set PIC1 as the master
    out PIC1_DATA,al
    nop
    mov al,0x02                 ; and PIC2 as the slave
    out PIC2_DATA,al
    nop
    mov al,0x01                 ; 8086 mode for both
    out PIC1_DATA,al
    nop
    out PIC2_DATA,al
    nop
    mov al,0xFF                 ; turn all interrupts off for now
    out PIC1_DATA,al
    nop
    out PIC2_DATA,al
    ret

kernelstart:
    cli
    lidt [idtr]                       ; load address of idt descriptor structure into idtr register
    call program_pic                  ; change overlapping interrupts by reprogramming PIC
    sti 
    mov eax,generic_interrupt_handler ; put address of our interrupt handler in offset for idt interrupt 1
    mov [idt + 1 * 8],ax                  
    mov word [idt + 1 * 8 + 2],CODE_SEG     ; set that we are in the code segment
    mov word [idt + 1 * 8 + 4],0x8E00       ; set present, ring, and 32 bit interrupt
    shr eax,16
    mov [idt + 1 * 8 + 6],ax                ; move upper 16 bits of isr address into idt entry
    int 1                                   ; execute trap to test handler
    hlt