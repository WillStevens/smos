; Serial or flash bootloader.
; This program sets up the UART on the 8051 to 19200 baud
;
; If P1.0 is low, it boots from the UART:
;
; The first two byte received from the UART are the number of bytes to
; follow (LSB first)
; The program is downloaded into address RAMSTART and then jumped to.
;
; If P1.0 is high, it boots from flash:
;
; Sector 0 - 256 bytes in length - is loaded into address RAMSTART and jumped to

RAMSTART equ 100h

        ORG 0000h

START:
		; The system has the following pin allocations for ports 1 and 3:
		
		; P1.0 - Input. Boot from flash or UART? Low = boot from UART
		; P1.1 - Output. DATA/#PROG. When low, MOVX accesses lower 64K, when high MOVX accesses upper 64K
		; P1.2 - Output. #SS for the display SPI interface. Bring low to start a new communications frame.
		; P1.3 - Input. AT keyboard data.
		; P1.4 - Input. Serial data in.
		; P1.5 - Output. Serial data out. (Used for both flash memory and display)
		; P1.6 - Output. Serial clock. (Used for both flash memory and display)
		; P1.7 - Output. #S for flash memory.
		; P3.0 - UART RXD
		; P3.1 - UART TXD
		; P3.2 - Input. Clock signal from keyboard. (#INT0)
		; P3.3
		; P3.4
		; P3.5
		; P3.6 - Bus #WR
		; P3.7 - Bus #RD

		; Setup P1 according to description above:
		; P1.0: Boot from flash (unless pulled low externally)
		; P1.1: Make sure we access lower 64K
		; P1.2: display #SS high
		; P1.3: Input
		; P1.4: Input
		; P1.7: flash #S high
        mov p1,#10011101b  

        ;Set all port 3 pins to input for second functions to work
        mov p3,#11111111b

        ;Set timer 1 to 8-bit reload timer
        ;Set timer 0 to 13-bit 8048 timer
        mov tmod,#00100000b

        ; Reload value for 1200 baud with 12MHz crystal and SMOD=1
        ; mov TH1,#204
        ; Reload value for 4800 baud with 12MHz crystal and SMOD=1
        ; mov TH1,#243
        ; Reload value for 19200 baud with 11.059MHz crystal and SMOD=1
        mov TH1,#253

        ;Enable timer 1, disable timer 0
        mov tcon,#01000000b

        ;Set the SMOD bit (bit 7 of PCON) to 1 for 19200 baud
        mov PCON,#10000000b

        ;Set serial interface to mode 1, receiver on.
        mov scon,#01010000b

        mov DPTR,#RAMSTART

        ; Now use state of p1.0 to decide whether to boot from the serial port, or from
        ; flash memory
        
        jb p1.0,BOOTFLASH
        
        MOV R0,#2

        setb c

WAITCHAR:
        jnb RI,WAITCHAR
        clr RI
        
        mov A,SBUF

        jc GETNUMBYTES

        movx @DPTR,A
        movx A,@DPTR
        inc DPTR

        jmp SKIP_CLRC

GETNUMBYTES:
        mov @r0,A
        djnz r0,SKIP_CLRC

        clr c

SKIP_CLRC:

        mov SBUF,A

WAITCHAROUT:
        jnb TI,WAITCHAROUT
        clr TI

        jc WAITCHAR

        djnz R2,WAITCHAR
        djnz R1,WAITCHAR

        LJMP RAMSTART

BOOTFLASH:

	mov r0,#17
	
	; Sector offset zero
	inc r0
	mov @r0,#0
	inc r0
	mov @r0,#0

	; Sector zero
	inc r0
	mov @r0,#0
	inc r0
	mov @r0,#0

	; RAM address should be equal to RAMSTART
	inc r0
	mov @r0,#LOW(RAMSTART)
	inc r0
	mov @r0,#HIGH(RAMSTART)

	; 256 bytes
	inc r0
	mov @r0,#0
	inc r0
	mov @r0,#0

BOOTFLASH_REENTRY:
	call ReadBytes
	
	ljmp RAMSTART

  
; Read upto 256 bytes from flash, beginning at the specified address
;
; The stack contains:
;   The flash address to read from (A23-A0)
;   The address to write to (R15-R0)
;   The number of bytes to read (N), where 0 means 256
;  
; The stack contains the flash address to read from, the ram address to write to, the number of bytes to program
; A7-A0 : 0 : A15-A8 : A23-A16 : R7-R0 : R15-R8 : N : 0 : <stacktop>
  
ReadBytes:
  ; Ignore high byte
  dec r0
  mov ar4,@r0
  dec r0
  mov dph,@r0
  dec r0
  mov dpl,@r0
  dec r0
  mov ar2,@r0
  dec r0
  mov ar1,@r0
  dec r0
  ; Ignore high byte
  dec r0
  push ar0
  mov ar0,@r0

  mov a,#3
  call CommandWithAddress

ReadBytesL1:
  call SPIGetByte
  movx @dptr,a
  inc dptr
  djnz r4,ReadBytesL1

  setb p1.7
  
  pop ar0
  dec r0
  ret

; Read a single byte from the specified address (in R0,R1,R2) into A
ReadByte:
  mov a,#3
  call CommandWithAddress
  call SPIGetByte

  setb p1.7
  ret

; Send a command and an address to the serial flash memory
; A contains the command byte
; (R2,R1,R0) contains the address
CommandWithAddress:
  clr p1.7
  
  call SPISendByte
  mov a,r2
  call SPISendByte
  mov a,r1
  call SPISendByte
  mov a,r0
  call SPISendByte

  ret
  
SPISendByte:
  push ar7
  mov r7,#8

SPISendLoop:
  rlc a
  mov p1.5,c
  setb p1.6
  clr p1.6
  djnz r7,SPISendLoop
  pop ar7
  ret

; Execution time = 3 + 6*8 + 4 = 55 cycles 
SPIGetByte:
  push ar7
  mov r7,#8
  
SPIGetLoop:
  setb p1.6
  mov c,p1.4
  rlc a
  clr p1.6 
  djnz r7,SPIGetLoop
  pop ar7
  ret
  

        end
