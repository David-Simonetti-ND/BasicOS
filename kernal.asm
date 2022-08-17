kernelstart:
    mov ebx, helloboot
    call print32

    cli
    hlt