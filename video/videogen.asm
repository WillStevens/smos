	list p=16f872,f=INHX32
	#include p16f872.inc

; A 256 by 256 pixel monochrome video generator. An external 4164 DRAM is used to store the video bitmap.
; Video data commands are received over the SPI port. The /SS pin is used to mark the end of the frame - whenever
; a byte is received, the /SS pin is checked, and if high it means that the frame has ended and the next byte received
; will be a new frame. This implies a minimum time between frames - need to work out what this should be.
;
; A frame is: X,Y,bytes
; X must be a multiple of 8 if there is pixel data
; If the frame ends without any data then the command sets the X and Y origin of the display
;
; PORTB outputs the address

; PORTC.0 = /WE
; PORTC.2 = /CAS = CCP1 - essential for pulsing /CAS during a video frame
; PORTC.7 = Data
; PORTC.1 = clear to pull video line to 0v
; PORTC.6 = /RAS
;
; PORTA.4 = TOCKI, timer 0 input, used for signalling start of frame
;
; SPI pins:
; PORTC.3 = SCL
; PORTC.4 = SDI
;

;Bits of config word are set as follows (from bit 13 to bit 0) i.e. CP1 = bit 13
;(CP1,CP0) = (1,1) : code protection off
;(DEBUG) = 1 : No in-circuit debugger
;(Bit 10) = 1 : Unimplemented
;(WRT) = 1 : Program mem may be written to using EECON
;(CPD) = 1 : Code protection off
;(LVP) = 0 : RB3 is digital I/O (no low voltage programming)
;(BODEN) = 1 : Brown out reset enabled
;(CP1,CP0) = (1,1) : code protection off
;(PWRTE) = 0 : Power up timer enabled
;(WDTE) = 0 : Watchdog timer disabled
;(FOSC1,FOSC0) = (1,0) HS Oscillator

COLOR_SYNC equ b'00000000'
COLOR_BLACK equ b'10000000'
COLOR_GRAY equ b'01000000'
COLOR_WHITE equ b'11000000'

FrameCounter equ 020h
VideoFlags   equ 021h
SyncCounter equ 022h
PatCounter equ 023h
RowCounter equ 024h
RowCounterTmp equ 025h

PixelCount equ 026h
CoordX equ 027h
CoordY equ 028h
Pixels equ 029h

RxFlags equ 02ah
RxFlagsExpectX equ 0
RxFlagsExpectY equ 1
RxFlagsExpectData equ 2
RxFlagsHad1Byte equ 3  ; Gets set if at least one byte of pixel data was received

OriginX equ 02bh
OriginY equ 02ch

PlotPixel macro
	local PlotPixelMain
	local PlotPixelDoNothing
	local PlotPixelDone
	local PlotPixelResetOrigin

; All paths from here to PlotPixelDone take 28 cycles = 5.6 microseconds
; For each path, on the sixteenth cycle, PORTC.1 is raised

	decfsz PixelCount,1
	goto PlotPixelMain

	incf PixelCount,1

	btfss PIR1,SSPIF
	goto PlotPixelDoNothing
	bcf PIR1,SSPIF

	; Has a new frame started? We detect this by seeing whether timer 0 has incremented

	movf TMR0,0
	btfss STATUS,Z
	movwf RxFlags ; TMR0 = 1 if we reach here, so RxFlags gets reset to 1
	btfss STATUS,Z ; We only want to reset TMR0 if it incremented.
	clrf TMR0

	; The carry bit is cleared here because we do rlf later on, and don't want it to be set then.
	bcf STATUS,C

	movf SSPBUF,0

	btfsc RxFlags,RxFlagsExpectX
	movwf CoordX

	;#### Interleaved instruction ####
	interleave
	;#### Interleaved instruction ####
	
	btfsc RxFlags,RxFlagsExpectY
	movwf CoordY

	; Put the byte into Pixels regardless, it will only get acted on if we're expecting data, when PixelCount will be updated
	movwf Pixels
	movlw 09h
	btfsc RxFlags,RxFlagsExpectData
	movwf PixelCount

	rlf RxFlags,1
	btfsc RxFlags,3
	bsf RxFlags,2
	bcf RxFlags,4

	goto PlotPixelDone

PlotPixelDoNothing

  nop
  nop
  nop
  nop
  nop
  nop
  
	nop
	nop
	nop

	;#### Interleaved instruction ####
    interleave
	;#### Interleaved instruction ####


	; If the frame has ended (i.e. TMR0 non-zero) but no pixel data was received, then reset the display
    ; origin.

	movf TMR0,0
	btfss STATUS,Z
  goto PlotPixelResetOrigin
	nop
	nop

	nop
	nop
	nop
	nop
	nop

	goto PlotPixelDone

PlotPixelResetOrigin
	movf CoordX,0
	btfss RxFlags,RxFlagsHad1Byte
	movwf OriginX
	movf CoordY,0
	btfss RxFlags,RxFlagsHad1Byte
	movwf OriginY

	goto PlotPixelDone

PlotPixelMain

	bsf PORTC,2
	movf CoordY,0
	movwf PORTB
    bcf PORTC,6	; Lower /RAS

	movf CoordX,0
	movwf PORTB
	bcf PORTC,7
	btfsc Pixels,7
	bsf PORTC,7

	bcf PORTC,0 ; Lower /WE
	bcf PORTC,2	; Lower /CAS
	bsf PORTC,0 ; Raise /WE

	;#### Interleaved instruction ####
    interleave
	;#### Interleaved instruction ####

	bsf PORTC,2 ; Raise /CAS

	rlf Pixels,1
	andlw 08h
	xorwf CoordX,1
	incf CoordX,1
	bcf CoordX,3
	xorwf CoordX,1

	movf CoordX,0
	andlw 07h
	btfsc STATUS,Z
	incf CoordY,1

	bsf PORTC,6 ; Raise /RAS

PlotPixelDone

	endm

	__config b'11111101110010'

	org 0000h

	goto Start
	nop
	nop
	nop

Start

	bsf STATUS,RP0
	; Setup timer0 as a counter so that the TOCKI input can be used to indicate the start of a data frame
	; Assign prescaler to the WDT, because we don't want it for Timer 0
    ;
	;Disable PORT-B weak pullups,INTEDG=1,Timer0 from T0CKI pin,T0SE=1 (high to low transition),Prescaler to WDT,prescaler=1:128
	movlw b'11111111'	
	movwf OPTION_REG
	bcf STATUS,RP0

PortInit
	movlw b'00000000'		
	bsf STATUS,RP0
	movwf TRISB
	movlw b'00011000'
	movwf TRISC
	movlw b'11111111'
	movwf TRISA
	bcf STATUS,RP0

	clrf PORTB
	movlw b'01000101'
	movwf PORTC	

	; Make sure RA5 is set as digital I/O s that #ss will work
	bsf STATUS,RP0
	movlw b'00000110'
	movwf ADCON1
	bcf STATUS,RP0

	; Now set up the PWM module to output a pattern with
	; a period of one instruction cycle, and a duty cycle of 25%
	; this is used for the /CAS signal. Don't enable it yet

	movlw b'00000000'
	bsf STATUS,RP0
	movwf PR2
	bcf STATUS,RP0

	clrf CCPR1L

	movlw b'00000100'
	movwf T2CON

	movlw b'00010000'
	movwf CCP1CON

	; Setup the SPI port as a slave, idle state is low, data transmitted on rising edge, use #ss control

	bsf STATUS,RP0
	bcf SSPSTAT,7
	bcf SSPSTAT,6
	bcf STATUS,RP0

	movlw b'00000100'
	movwf SSPCON
	bsf SSPCON,SSPEN

VarInit
	movlw 098h
	movwf FrameCounter

    movlw 06h
	movwf SyncCounter

	clrf VideoFlags

	movlw 00h
	movwf RowCounter
	
	clrf OriginX
	clrf OriginY

	movlw 01h
	movwf RxFlags
	movwf PixelCount

	; Initialise these vars as though we've received a a byte to plot
	; If this is commented out then test pattern should be displayed
	movlw 09h
	movwf PixelCount
	movlw 020h
	movwf CoordX
	movwf CoordY
	movlw 055h
	movwf Pixels

; Write a test pattern into RAM
RamInit

RamInitOuterLoop
	movf RowCounter,0
	movwf PORTB

	bcf PORTC,6 ; Lower /RAS

	clrf PatCounter

	clrf PORTB
RamInitLoop

	; If on row 32 (mod 64) or column 32 (mod 64), or row = column (ignoring bit 6), then set pixel 
	
	bcf PORTC,7
	movf PatCounter,0
	xorwf RowCounter,0
	andlw b'10111111'
	btfsc STATUS,Z
	bsf PORTC,7

	movf RowCounter,0
	andlw b'00111111'
	sublw 020h
	btfsc STATUS,Z
	bsf PORTC,7
	movf PatCounter,0
	andlw b'00111111'
	sublw 020h
	btfsc STATUS,Z
	bsf PORTC,7

	bcf PORTC,0 ; Lower /WE
	bcf PORTC,2 ; Lower /CAS
	bsf PORTC,0 ; Raise /WE
	bsf PORTC,2	; Raise /CAS

	incf PORTB,1

	incfsz PatCounter,1
	goto RamInitLoop

    bsf PORTC,6	; /Raise RAS

	incfsz RowCounter,1
	goto RamInitOuterLoop

	clrf PORTB
	movlw b'01000101'
	movwf PORTC	

Main

FrameLoop
	; The RowCounter / FrameCounter logic below is interleaved with setting/clearing of some PORTC bits

	;**** 1.4us front porch ***

	; Save RowCounter+OriginY in RowCounterTmp for use later when RAS is lowered for start of row
	movf RowCounter,0
	addwf RowCounterTmp
	movlw b'00000001'
	xorwf VideoFlags,1
	; Don't start incrementing the row counter unless the frame counter is < 136
	movf FrameCounter,0
	sublw 088h
	movlw 00h

	;**** 4.8us line sync ****

	;#### Interleaved instructions ####
	bcf PORTC,1	; Signal level to 0v
	bsf PORTC,6	; Raise RAS
	;#### Interleaved instructions ####
	
	btfsc STATUS,C
	movlw 01h
	addwf RowCounter,0

	; If row counter overflows, don't incrememnt it
	btfss STATUS,C
	movwf RowCounter

	btfss VideoFlags,0
	incf FrameCounter,1

#define interleave bsf PORTC,1
	PlotPixel
#undefine interleave

	movf RowCounterTmp,0
	movwf PORTB
	bcf PORTC,6 ; Lower /RAS

	nop
	nop
	nop
	nop
	nop

	nop
	nop
	movf OriginY,0
	movwf RowCounterTmp  ; Put OriginY here for use next time around the frame loop
	movf OriginX,0

	movwf PORTB 

	; Enable PWM
	movlw b'00011111'
	movwf CCP1CON

    ; **** 52 image data ****

	;1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;2
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;3
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;4
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;5
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;6
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;7
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;8
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;9
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;10
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;11
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;12
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;13
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;14
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;15
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;16
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;17
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;18
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;19
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;20
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;21
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;22
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;23
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;24
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;25
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;26
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;27
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;28
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;29
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;30
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;31
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;32
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;33
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;34
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;35
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;36
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;37
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;38
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;39
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;40
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;41
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;42
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;43
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;44
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;45
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;46
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;47
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;48
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;49
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;50
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;51
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	incf PORTB,1
	;52
	incf PORTB,1	

	; Disable PWM
	clrf CCP1CON
  
	decfsz FrameCounter,1
	goto FrameLoop

	bsf PORTC,6 ; Raise RAS

; Vertical sync is 6 short syncs, 5 long syncs, 5 short syncs
VertSync  

; Short sync: COLOR_SYNC for 2 microseconds, black for 30 microseconds
ShortSync
    bcf PORTC,1
    clrf RowCounter ; This needs to be done before starting frameloop again - doesn't matter that it is done
					 ; several times over
	nop
	nop
	nop

    nop
    nop
	nop
	nop
	nop

	bsf PORTC,1
	nop
	nop
	nop
	nop

; 5.6 microseconds
#define interleave nop
	PlotPixel
#undefine interleave

	; make it upto 6
	nop
	nop

    ;20 microseconds
	call Delay16
	call Delay2
	call Delay2
    
    nop
    nop
	nop
	nop
	nop

    movlw 05h
	nop
	nop
	nop

	nop
	nop
	nop
    decfsz SyncCounter,1
	goto ShortSync

    movwf SyncCounter

; Long sync: COLOR_SYNC for 30 microseconds, black for 2 microseconds
LongSync
    bcf PORTC,1
    nop
	nop
	nop
	nop

; 5.6 microseconds
#define interleave nop
	PlotPixel
#undefine interleave

	; make it upto 6
	nop
	nop

    ;20 microseconds
	call Delay16
	call Delay2
	call Delay2

    nop
    nop
	nop
	nop
	nop

    decfsz SyncCounter,1
    goto LongSyncNoEnd
	goto LongSyncEnd

LongSyncNoEnd
	nop
	nop

    nop
	nop
	nop
	nop
	nop

	nop
	nop
	nop
	nop
	nop

	bsf PORTC,1
	nop
	nop
	goto LongSync

LongSyncEnd
	nop

    nop
	nop
	nop
	nop
	nop

	nop
	nop
	nop
	nop
	nop

	bsf PORTC,1
	nop
	nop
    movlw 05h
    movwf SyncCounter

; Short sync: COLOR_SYNC for 2 microseconds, black for 30 microseconds
ShortSync2
    bcf PORTC,1
	nop
	nop
	nop
	nop

	nop
	nop
	nop
    movlw 098h
    movwf FrameCounter

	bsf PORTC,1
	nop
	nop
	nop
	nop

; 5.6 microseconds
#define interleave nop
	PlotPixel
#undefine interleave

	; make it upto 6
	nop
	nop

    ;20 microseconds
    call Delay16
    call Delay2
    call Delay2


	nop
	nop
	nop
	nop
	nop

	nop
	nop
	nop
	nop

    movlw 06h
    decfsz SyncCounter,1
	goto ShortSyncContinue
    movwf SyncCounter
    goto FrameLoop   
ShortSyncContinue
	goto ShortSync2


Delay16
    call Delay2
    call Delay2
    call Delay2
    call Delay2
Delay8
    call Delay2
    call Delay2
    call Delay2

Delay2
    nop
    nop
	nop


    nop
    nop
	nop
    return

	end