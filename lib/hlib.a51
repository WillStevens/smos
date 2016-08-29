; Hardware access library, with parameters and return values passed via the
; data stack for compatability with MC.
;
; The MC data stack uses 16-bit words, so when a function requires a byte to be passed
; as a parameter, a 16-bit word is passed and the upper 8-bits ignored. (See for example
; the PageProgram function). 
;
; This library provides functions for:
;
; Reading the contents of some 8051 registers for diagnostic purposes.
; Sending and receiving bytes through the 8051 serial port.
;
; Reading and writing to serial flash memory. 
;
; Writing data to the display (i.e. PIC-based video generator with SPI interface, sharing SPI lines with flash memory)
;
; Setting up and using the keyboard

; Static data used by the hardware access library is kept at the top of internal RAM (at the time of
; re-examining this comment, it seems that only the keyboard routines use this), and flags
; needed are kept at the start of bit addressable memory

KEYBOARD_DATA 		equ 07fh
KEYBOARD_BITCOUNT	equ 07eh
KEYBOARD_LASTKEY 	equ 07dh  ; The scan code of the last key pressed
KEYBOARD_STATE 		equ 020h

KEYBOARD_RELEASE 	equ 0	 ; Is the next scan code received going to be a release code?
KEYBOARD_SHIFT 		equ 1	 ; Shift pressed
KEYBOARD_CAPSLOCK 	equ 2    ; Caps-lock on?
KEYBOARD_RXP        equ 3    ; Parity bit
KEYBOARD_EXP_STOP_BIT equ 4  ; Are we expecting the stop bit?

;A bitmap of depressed keys is kept in external RAM. The bitmap is done in such away that for
; scancodes not prefixed with E0, the scancode gives the address in this bitmap. Since the highest
; such scancode is 83h (for key F7), we use 17 bytes, allowing for upto 136 keys, so the
; bitmap is in addresses 0000h-0010h. (if moved, this must start on a 256 byte boundary).

;TODO - At some point, scancodes prefixed with E0 will be mapped into unused places in the range 0-135

KEYPRESS_BITMAP equ 0000h

; The display bitmap is organised as 32 columns of 8 by 256 pixels
; The total memory required is 32*256 = 8192 bytes 
; Resides in addresses 0100h-020FFh. (if moved, this must start on a 256 byte boundary)

DISPLAY_BITMAP equ 0100h
DISPLAY_BITMAP_END equ 2100h

; Address of the register containing the bit used to switch data pointers

AUXR equ 08Eh
AUXR1 equ 0A2h

; Some utility routines

BitNumberLookup:
	db 01h
	db 02h
	db 04h
	db 08h
	db 10h
	db 20h
	db 40h
	db 80h

BitMaskLookup:
	db 01h
	db 03h
	db 07h
	db 0fh
	db 1fh
	db 3fh
	db 7fh
	db 0ffh

BitMaskFlipLookup:
	db 0ffh
	db 7fh
	db 3fh
	db 1fh
	db 0fh
	db 07h
	db 03h
	db 01h

DeviceInit:

; Configure P1 pins.
; No need to do this if P1 was set correctly on boot.
; This is included here so that it can be called if bootloader is not up-to-date with hardware.
; Make sure /S is high, clock is low, and set P1.4 as an input.
; P1.2 is connected to /SS on display PIC, so set it high
; P1.3 is AT keyboard input, so set it high
; P1.1 is clear so that MOVX will access the lower 64KBytes of RAM

  mov p1,#10011101b  
  
; Make sure that the EXTRAM bit (bit 1) is set in the AUXR register (address 8Eh)
; otherwise access to low addresses using MOVX will access internal XRAM on the 80C51RD2-UM

  mov AUXR,#02h

  ret  
  
InterruptsOn:
  setb EA
  ret
  
InterruptsOff:
  clr EA
  ret
  
LoMem:
  mov p1,#10011101b  
  ret

HiMem:
  mov p1,#10011111b  
  ret
  
; Push the contents of the stack pointer onto the data stack.

GetSP:
  inc r0
  mov @r0,sp
  inc r0
  mov @r0,#0
  ret

  
; Push the contents of the data stack pointer R0 onto the data stack.

GetR0:
  mov a,r0
  inc r0
  mov @r0,a
  inc r0
  mov @r0,#0
  ret

; Get the value fromm the data stack and set R0 to this - useful for returning data stack to a known state
SetR0:
  dec r0
  mov a,@r0
  dec r0
  mov r0,a
  ret


; Dereference the address on the stack - used because @8 treats address with zero msb as internal ram
Dereference:
  mov dph,@r0
  dec r0
  mov dpl,@r0
  movx a,@dptr
  mov @r0,a
  inc r0
  mov @r0,#0
  ret
  
; Wait for a byte to be received on the serial port, then push the byte onto
; the data stack.

SerGetChar:
  jnb ri,SerGetChar
  clr ri
  inc r0
  mov @r0,sbuf
  inc r0
  mov @r0,#0
  ret


; Send a byte to the serial port, and wait for it to be transmitted
; The stack contains the byte to be sent

SerPutChar:
  dec r0
  mov sbuf,@r0
  dec r0
SerPutCharLoop:
  jnb ti,SerPutCharLoop
  clr ti
  ret

  
; Functions for using an SPI flash memory on the following pins:
;
; P1.4 = D0
; P1.5 = DI
; P1.6 = C
; P1.7 = /S
;
; The part that was used in the circuit that these routines were developed on was
; an AMIC 25L032

; Wait for the flash memory to complete a write operation  
  
WaitForWriteComplete:
  call IsWriteComplete
  jnz WaitForWriteComplete
  ret

; Examine the 'Write in Progress' bit to see whether the write has completed
; On return, A will be 1 if a write is in progress, zero otherwise.

IsWriteComplete:
  clr p1.7

  mov a,#5
  call SPISendByte
  call SPIGetByte
  anl a,#1

  setb p1.7
  ret

  
; Erase a 4 Kbyte sector
; The stack contains the upper 16 bits of the address to erase
; A15-A8 : A23-A16 : <stacktop>

EraseSector:
  mov ar2,@r0
  dec r0
  mov ar1,@r0
  dec r0
  push ar0
  mov r0,#0
  
  ; Write enable
  clr p1.7
  
  mov a,#6
  call SPISendByte
  
  setb p1.7
  
  ; Erase sector
  mov a,#32
  call CommandWithAddress

  setb p1.7
  
  pop ar0
  dec r0
  jmp WaitForWriteComplete

  
; Erase the whole chip

EraseChip:  
  ; Write enable
  clr p1.7
  
  mov a,#6
  call SPISendByte
  
  setb p1.7
  
  ; Erase chip
  mov a,#96
  call CommandWithAddress

  setb p1.7
  
  jmp WaitForWriteComplete
  
  
; Write upto 256 bytes to flash, beginning at the specified address
;
; The stack contains:
;   The flash address to program (A23-A0)
;   The address to read from (R15-R0)
;   The number of bytes to program (N), where 0 means 256
; A7-A0 : 0 : A15-A8 : A23-A16 : R7-R0 : R15-R8 : N : 0 : <stacktop>

PageProgram:
  call WaitForWriteComplete
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


  ; Write enable
  clr p1.7
  
  mov a,#6
  call SPISendByte
  
  setb p1.7
  
  ; Page program
  mov a,#2
  call CommandWithAddress

  ; Now write however many bytes need to be written
PageProgramL1:
  movx a,@dptr
  inc dptr
  call SPISendByte
  djnz r4,PageProgramL1

  setb p1.7
  pop ar0
  dec r0
  ret

  
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

; Write to the display
;
; On the stack are the following words, only the lsbyte of x,y,length used: <data-ptr> <length> <y> <x>
; The display can accept one byte every 64us, but can only process one pixel every 64us, if no byte is sent
; during the interval.
; So x,y and the first data byte can be sent with a delay of 64us in between, but all other data bytes must have a
; delay of 566 microseconds in between.
; (Here we make no assumption about how long SPISendByte takes, but in practice with a 12MHz clock it will
; take close to 64us, so to speed things up these delays could be reduced significantly).

DisplayWrite:
  clr p1.2
  
  ; Get the x-coordinate
  dec r0
  mov a,@r0
  dec r0
  
  call SPISendByte

  mov r7,#10
  call DelayMicroSeconds
  
  ; Get the y-coordinate
  dec r0
  mov a,@r0
  dec r0
  
  call SPISendByte

  mov r7,#10
  call DelayMicroSeconds

  ; Get the length into r6
  dec r0
  mov ar6,@r0
  dec r0

  mov dph,@r0
  dec r0
  mov dpl,@r0
  dec r0

DisplayWriteLoop:

  movx a,@dptr
  inc dptr
  
  call SPISendByte

  mov r7,#250
  call DelayMicroSeconds
  
  djnz r6,DisplayWriteLoop
  
  setb p1.2
  
  ret

DisplayOrigin:
  clr p1.2
  
  ; Get the x-coordinate
  dec r0
  mov a,@r0
  dec r0
  
  call SPISendByte

  mov r7,#10
  call DelayMicroSeconds
  
  ; Get the y-coordinate
  dec r0
  mov a,@r0
  dec r0
  
  call SPISendByte

  mov r7,#10
  call DelayMicroSeconds

  setb p1.2
  
  ret

; Delay for the length specified in r7. i.e. r7 * 2 microseconds. The call and return take 4 microseconds
DelayMicroSeconds:
	djnz r7,DelayMicroSeconds
	ret

DisplayLowerPin:
	clr p1.2
	ret
	
DisplayRaisePin:
	setb p1.2
	ret
	
DisplaySendByte:
	dec r0
	mov a,@r0
	dec r0
	call SPISendByte
	
	ret

; Clear the display bitmap - depends on the fact that the display bitmap starts on a 256
; byte boundary, and is a multiple of 256 bytes in length

ClearDisplayBitmap:
	mov dptr,#DISPLAY_BITMAP

ClearDisplayBitmapLoop:
	clr a
	movx @dptr,a
	inc dptr
	mov a,#HIGH(DISPLAY_BITMAP_END)
	cjne a,dph,ClearDisplayBitmapLoop
	
	ret	

; Synchronie the entire display with the in-memory bitmap
SyncDisplayBitmap:
	mov dptr,#DISPLAY_BITMAP
	
SyncDisplayBitmapLoop:
	clr p1.2
  
	; Get the x-coordinate
	mov a,dph
	clr c
	subb a,#HIGH(DISPLAY_BITMAP)
	rl a
	rl a
	rl a
	call SPISendByte

	mov r7,#10
	call DelayMicroSeconds
  
	clr a
	call SPISendByte

	mov r7,#10
	call DelayMicroSeconds

SyncDisplayBitmapLoop2:

	movx a,@dptr
	inc dptr
  
	call SPISendByte

	mov r7,#250
	call DelayMicroSeconds
	clr a
	cjne a,dpl,SyncDisplayBitmapLoop2
  
	setb p1.2
  
	mov a,#HIGH(DISPLAY_BITMAP_END)
	cjne a,dph,SyncDisplayBitmapLoop
	
	ret	
	
; Write to both the display and the bitmap
;
; On the stack are the following words, only the lsbyte of x,y,length used: <data-ptr> <length> <y> <x>
; Registers used: R7, R6, DPL, DPH

BitmapDisplayWrite:
  clr p1.2
  
  ; Get the x-coordinate
  dec r0
  mov a,@r0
  
  call SPISendByte

  mov a,@r0
  rr a
  rr a
  rr a
  add a,#HIGH(DISPLAY_BITMAP)
  mov dph,a
  dec r0
  
  mov r7,#4
  call DelayMicroSeconds
  
  ; Get the y-coordinate
  dec r0
  mov a,@r0
  
  call SPISendByte

  mov dpl,@r0
  dec r0
  
  mov r7,#10
  call DelayMicroSeconds

  ; Get the length into r6
  dec r0
  mov ar6,@r0
  dec r0
  
  ; Switch to the second dptr
  inc auxr1
  
  ; Get the source data address
  mov dph,@r0
  dec r0
  mov dpl,@r0
  dec r0

BitmapDisplayWriteLoop:

  movx a,@dptr
  inc dptr
  
  ; Switch to the first dptr to put the data into the bitmap
  inc auxr1
      
  movx @dptr,a
  inc dptr
  
  ; Switch back to the second dptr
  inc auxr1
  
  call SPISendByte

  mov r7,#250
  call DelayMicroSeconds
  
  djnz r6,BitmapDisplayWriteLoop
  
  setb p1.2
  
  ; Switch back to the first dptr before leaving
  inc auxr1
  
  ret

; Synchronise the specified part of the display with the bitmap
;
; On the stack are the following words, only the lsbyte of x,y,length used: <length> <y> <x>
; Registers used: R7, R6, DPL, DPH

BitmapDisplaySync:
  clr p1.2
  
  ; Get the x-coordinate
  dec r0
  mov a,@r0
  
  call SPISendByte

  mov a,@r0
  rr a
  rr a
  rr a
  add a,#HIGH(DISPLAY_BITMAP)
  mov dph,a
  dec r0
  
  mov r7,#4
  call DelayMicroSeconds
  
  ; Get the y-coordinate
  dec r0
  mov a,@r0
  
  call SPISendByte

  mov dpl,@r0
  dec r0
  
  mov r7,#10
  call DelayMicroSeconds

  ; Get the length into r6
  dec r0
  mov ar6,@r0
  dec r0
  
BitmapDisplaySyncLoop:

  movx a,@dptr
  inc dptr
    
  call SPISendByte

  mov r7,#250
  call DelayMicroSeconds
  
  djnz r6,BitmapDisplaySyncLoop
  
  setb p1.2
    
  ret
  
ClearScreen:
	call ClearDisplayBitmap
	jmp SyncDisplayBitmap
	
 ; Plot a pixel in the bitmapped display. On the stack are: <y> <x>
 ; No return value
PlotPixel:
    ; Get the x-coordinate
    dec r0
    mov a,@r0

    ; Get the bitmask for the bit and put it into R7
    ; Note that in the display bitmap, the least significant bit of each byte
    ; is the rightmost displayed pixel, so we must Xor with 7 before calling
    ; BitNumberLookup
    anl a,#07h
    xrl a,#07h
	mov dptr,#BitNumberLookup
	movc a,@a+dptr    
    mov r7,a

    mov a,@r0
    dec r0
    anl a,#0f8h
    mov r6,a		; Save x coordinate in R6 for use later
    
    rr a
    rr a
    rr a
    
    add a,#HIGH(DISPLAY_BITMAP)
    mov dph,a
  
    ; Get the y-coordinate
    dec r0
    mov dpl,@r0
	dec r0
	
    ; Get the byte containing the pixel, set the pixel, then write it back to the bitmap
    movx a,@dptr
  
    orl a,r7
    
    movx @dptr,a
    

    ; Now send the instruction to the display to plot the pixel
	clr p1.2

	; Get the x coordinate from R6
	mov a,r6
  
	call SPISendByte

	mov r7,#10
	call DelayMicroSeconds
  
	; Get the y-coordinate from DPL
	mov a,dpl
  
	call SPISendByte

	mov r7,#10
	call DelayMicroSeconds

	movx a,@dptr
  
	call SPISendByte
  
	mov r7,#250
	call DelayMicroSeconds

	setb p1.2

	ret
    

; Clear a pixel in the bitmapped display. On the stack are: <y> <x>
; No return value
UnPlotPixel:
	ret

TestPixel:
	ret
	
; Routines for handling an MF-II keyboard
	
; This assumes that DATA/#PROG is low, so that the ISR can be setup
KeyboardSetup:
	mov KEYBOARD_DATA,#0h
	mov KEYBOARD_BITCOUNT,#10
	mov KEYBOARD_STATE,#0
	mov KEYBOARD_LASTKEY,#0
	
	; Set the ISR for external interrupt 0
	mov dptr,#0003h
	
	mov a,#02h ; LJMP instruction
	movx @dptr,a
	inc dptr
	mov a,#HIGH(KeyboardISR)
	movx @dptr,a
	inc dptr
	mov a,#LOW(KeyboardISR)
	movx @dptr,a
	
	; Set external interrupt 0 to be edge triggered
	setb IT0
	
	; Enable the interrupt
	setb EX0

	ret

; When a key is pressed, this might get called every 100 microseconds for a keyboard with a 10KHz clock,
;  so it must be fast.
; In the worst case it will take 11 machine cycles from the falling edge on INT0 to the beginning of KeyboardISR.
;
; Note that we don't care about the state of AUXR1.0 (the bit which chooses which data
; pointer is in use) : we will make use of whichever data pointer it is set to use, then
; restore the data pointer afterwards.
KeyboardISR:
  
    push psw
  
    jb KEYBOARD_STATE.KEYBOARD_EXP_STOP_BIT,KeyboardISR_ProcessData
    
    mov c,p1.3
    
    djnz KEYBOARD_BITCOUNT,KeyboardISR_NextBit
    
    ; At this point, KEYBOARD_DATA = 7:6:5:4:3:2:1:0
    ; Carry = stop bit
    
    mov KEYBOARD_STATE.KEYBOARD_RXP,c
    setb KEYBOARD_STATE.KEYBOARD_EXP_STOP_BIT

    pop psw
    reti
    
KeyboardISR_NextBit:
	xch a,KEYBOARD_DATA
	rrc a
	xch a,KEYBOARD_DATA
	
    pop psw
	reti

KeyboardISR_ProcessData:
	clr KEYBOARD_STATE.KEYBOARD_EXP_STOP_BIT
	
    xch a,KEYBOARD_DATA
    
    jb KEYBOARD_STATE.KEYBOARD_RELEASE,KeyboardISR_ProcessRelease
    
    cjne a,#0f0h,KeyboardISR_ProcessPressCode
    
    setb KEYBOARD_STATE.KEYBOARD_RELEASE
	mov KEYBOARD_BITCOUNT,#10    

	xch a,KEYBOARD_DATA

    pop psw
    reti
	
KeyboardISR_ProcessPressCode:

	; Set the bit in the keypress bitmap

	push acc
	push dph
	push dpl
	push ar0
	
	; Save A so that we can get it back in a moment
	mov r0,a
	
	anl a,#07h
	mov dptr,#BitNumberLookup
	movc a,@a+dptr
	
	; Store the bit number in R0, and get the original A back
	xch a,r0
	
	mov dph,#HIGH(KEYPRESS_BITMAP)
	swap a
	rl a
	anl a,#1fh
	mov dpl,a
	
	movx a,@dptr
	orl a,r0
	movx @dptr,a
	
	pop ar0
	pop dpl
	pop dph
	pop acc

	; If shift has been released, reset the shift flag
	cjne a,#012h,PressNotLShift
	setb KEYBOARD_STATE.KEYBOARD_SHIFT
	jmp KeyboardISR_ExitAfterCode

PressNotLShift:
	cjne a,#059h,PressNotRShift
	setb KEYBOARD_STATE.KEYBOARD_SHIFT
	jmp KeyboardISR_ExitAfterCode
	
PressNotRShift:
    
	mov KEYBOARD_LASTKEY,a
	;mov KEYBOARD_LASTKEY,#2

	jmp KeyBoardISR_ExitAfterCode
	
KeyboardISR_ProcessRelease:
    clr KEYBOARD_STATE.KEYBOARD_RELEASE

	; Clear the bit in the keypress bitmap
    
   	push acc
	push dph
	push dpl
	push ar0
	
	; Save A so that we can get it back in a moment
	mov r0,a
	
	anl a,#07h
	mov dptr,#BitNumberLookup
	movc a,@a+dptr
	
	; Invert the bit mask so that we can used it with anl later
	cpl a
	
	; Store the bit number in R0, and get the original A back
	xch a,r0
	
	mov dph,#HIGH(KEYPRESS_BITMAP)
	swap a
	rl a
	anl a,#1fh
	mov dpl,a
	
	movx a,@dptr
	anl a,r0
	movx @dptr,a
	
	pop ar0
	pop dpl
	pop dph
	pop acc
 
	; If shift has been released, reset the shift flag
	cjne a,#012h,ReleaseNotLShift
	clr KEYBOARD_STATE.KEYBOARD_SHIFT	
	jmp KeyboardISR_ExitAfterCode
	
ReleaseNotLShift:
	cjne a,#059h,ReleaseNotRShift
	clr KEYBOARD_STATE.KEYBOARD_SHIFT

ReleaseNotRShift:
KeyboardISR_ExitAfterCode:

	mov KEYBOARD_BITCOUNT,#10
	
KeyboardISR_Exit:
	xch a,KEYBOARD_DATA
	
    pop psw
	reti
	
ScanCodeLookup:
; 00
	db 0
	db 0
	db 0
	db 0
	db 0
	db 0
	db 0
	db 0

	db 0
	db 0
	db 0
	db 0
	db 0
	db 0
	db '`'
	db 0
; 10
	db 0
	db 0
	db 0
	db 0
	db 0
	db 'q'
	db '1'
	db 0

	db 0
	db 0
	db 'z'
	db 's'
	db 'a'
	db 'w'
	db '2'
	db 0
; 20
	db 0
	db 'c'
	db 'x'
	db 'd'
	db 'e'
	db '4'
	db '3'
	db 0

	db 0
	db ' '
	db 'v'
	db 'f'
	db 't'
	db 'r'
	db '5'
	db 0
; 30
	db 0
	db 'n'
	db 'b'
	db 'h'
	db 'g'
	db 'y'
	db '6'
	db 0

	db 0
	db 0
	db 'm'
	db 'j'
	db 'u'
	db '7'
	db '8'
	db 0
; 40
	db 0
	db ','
	db 'k'
	db 'i'
	db 'o'
	db '0'
	db '9'
	db 0

	db 0
	db '.'
	db '/'
	db 'l'
	db ';'
	db 'p'
	db '-'
	db 0
; 50
	db 0
	db 0
	db ''''
	db 0
	db '['
	db '='
	db 0
	db 0

	db 0
	db 0
	db 10
	db ']'
	db 0
	db '\'
	db 0
	db 0
	
ShiftScanCodeLookup:
; 00
	db 0
	db 0
	db 0
	db 0
	db 0
	db 0
	db 0
	db 0

	db 0
	db 0
	db 0
	db 0
	db 0
	db 0
	db '~'
	db 0
; 10
	db 0
	db 0
	db 0
	db 0
	db 0
	db 'Q'
	db '!'
	db 0

	db 0
	db 0
	db 'Z'
	db 'S'
	db 'A'
	db 'W'
	db '"'
	db 0
; 20
	db 0
	db 'C'
	db 'X'
	db 'D'
	db 'E'
	db '$'
	db '#'
	db 0

	db 0
	db ' '
	db 'V'
	db 'F'
	db 'T'
	db 'R'
	db '%'
	db 0
; 30
	db 0
	db 'N'
	db 'B'
	db 'H'
	db 'G'
	db 'Y'
	db '^'
	db 0

	db 0
	db 0
	db 'M'
	db 'J'
	db 'U'
	db '&'
	db '*'
	db 0
; 40
	db 0
	db '<'
	db 'K'
	db 'I'
	db 'O'
	db ')'
	db '('
	db 0

	db 0
	db '>'
	db '?'
	db 'L'
	db ':'
	db 'P'
	db '_'
	db 0
; 50
	db 0
	db 0
	db '@'
	db 0
	db '{'
	db '+'
	db 0
	db 0

	db 0
	db 0
	db 10
	db '}'
	db 0
	db '|'
	db 0
	db 0

	
; Wait for a keypress, and return it on the data stack
WaitKey:
	mov a,KEYBOARD_LASTKEY
	jz WaitKey
	
	mov KEYBOARD_LASTKEY,#0
	
	; If this is the scan code for shift
	
	mov dptr,#ScanCodeLookup
	jnb KEYBOARD_STATE.KEYBOARD_SHIFT,WaitKeyNoShift
	mov dptr,#ShiftScanCodeLookup
WaitKeyNoShift:

	movc a,@a+dptr

    inc r0
    mov @r0,a
    inc r0
    mov @r0,#0
    ret

; Parameters:
;	The key to test for (i.e. the address in the keyboad bitmap)
; Returns:
;   non-zero (not necessarily 1) if the key is pressed, 0 if not

TestKey:

	dec r0
	mov a,@r0
	
	; A contains the key to test for
	
	anl a,#07h
	mov dptr,#BitNumberLookup
	movc a,@a+dptr
	
	; Temporarily store the bit number in @R0, and get the original A back
	xch a,@r0
	
	mov dph,#HIGH(KEYPRESS_BITMAP)
	swap a
	rl a
	anl a,#1fh
	mov dpl,a
	
	movx a,@dptr
	anl a,@r0
	
	mov @r0,a
	inc r0
	mov @r0,#0
	
	ret
	
