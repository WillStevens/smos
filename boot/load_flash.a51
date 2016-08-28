; Load sectors 2 to 32 (not 0) into RAM, starting at address 200h
; Finally re-call part of the boot loader to load sector 1 at address 100h, then
; start executing at 100h

; This must be on a 256 byte boundary
; It must also be the same as the address used by serboot.a51

LOAD_ADDRESS equ 0100h

; These are the address of these routines from setboot.a51

ReadBytes         equ 0061h
BOOTFLASH_REENTRY equ 005bh

  org 100h

Start:
  mov a,#'B'
  call PutChar
  mov a,#'o'
  call PutChar
  mov a,#'o'
  call PutChar
  mov a,#'t'
  call PutChar
  mov a,#'e'
  call PutChar
  mov a,#'r'
  call PutChar
  mov a,#' '
  call PutChar
  mov a,#'1'
  call PutChar
  mov a,#'.'
  call PutChar
  mov a,#'0'
  call PutChar
  mov a,#10
  call PutChar
  mov a,#13
  call PutChar

  mov r0,#17

; Sector offset zero
  inc r0
  mov @r0,#0
  inc r0
  mov @r0,#0

; Sector 2
  inc r0
  mov @r0,#2
  inc r0
  mov @r0,#0

; RAM address 0x2100
  inc r0
  mov @r0,#LOW(LOAD_ADDRESS)
  inc r0
  mov @r0,#HIGH(LOAD_ADDRESS+256)

ReadBytesLoop:
  
; 256 bytes
  inc r0
  mov @r0,#0
  inc r0
  mov @r0,#0

  call ReadBytes

; ReadBytes doesn't touch the data stack so...
  inc r0
  inc r0
  
; Increment the sector number
  inc r0
  inc @r0
  inc r0

; Increase the RAM address by 256 
  inc r0
  inc r0
  inc @r0
    
  cjne @r0,#40h,ReadBytesLoop
  
; Set RAM address to the LOAD_ADDRESS
  mov @r0,#HIGH(LOAD_ADDRESS)
  dec r0
  
  dec r0
  dec r0

; Set sector number to 1
  mov @r0,#1
  inc r0
  
  inc r0
  inc r0

  inc r0
  inc r0
  
; Jump to the location in serboot.a51 that calls ReadBytes then jumps to the start address at 0100h
  jmp BOOTFLASH_REENTRY

PutChar:
  mov sbuf,a
PutCharLoop:
  jnb ti,PutCharLoop
  clr ti
  ret
  
end
