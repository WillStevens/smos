	list p=16f84,f=INHX32
	#include p16f84.inc

;Bits of config word are set as follows (from bit 13 to bit 0) i.e. CP1 = bit 13
;Bit 13-4 : (/CP) = 1 : code protection off
;Bit 3   : (/PWRTE) = 0 : Power up timer enabled
;Bit 2   : (WDTE) = 0 : Watchdog timer disabled
;Bit 1-0 : (FOSC1,FOSC0) = (1,1) RC oscillator

	__config b'11111111110011'


; Pins used:
; RB7-RB0 : Address / data output
; RA0 : 8031 reset pin (active high)
; RA1 : 74373 latch pin (active high)
; RA2 : RAM /WR pin (active low)
; RA3 : DATA//PROG pin (to be pulled down in order to write to lower 64k)
; RA4 : /OE for pulling high-address bits to 0v


AddressByte equ 020h
DataByte equ 021h

	org 0000h

	goto Start
	nop
	nop
	nop

Start

	nop
	nop
	nop
	nop
	nop

PortInit
    ; Initially make sure that ports A and B aren't outputting anyting
	movlw b'11111111'		
	bsf STATUS,RP0
	movwf TRISA
	movwf TRISB
	bcf STATUS,RP0

	; Set the 8031 reset pin high - all other pins remain high impedance
	movlw b'11111101'
	movwf PORTA
	bsf STATUS,RP0
	movlw b'11111110'
	movwf TRISA
	bcf STATUS,RP0

	; hi-address set to 0, DATA//PROG set low, 6116 /WR pin high, 8031 reset pin high, 74373 latch pin low
	movlw b'11100101'
	movwf PORTA
	bsf STATUS,RP0
	movlw b'11100000'
	movwf TRISA
	bcf STATUS,RP0

	clrf AddressByte

	movlw .117
	call WriteNextByte
	movlw .144
	call WriteNextByte
	movlw .157
	call WriteNextByte
	movlw .117
	call WriteNextByte
	movlw .176
	call WriteNextByte
	movlw .255
	call WriteNextByte
	movlw .117
	call WriteNextByte
	movlw .137
	call WriteNextByte
	movlw .32
	call WriteNextByte
	movlw .117
	call WriteNextByte
	movlw .141
	call WriteNextByte
	movlw .253
	call WriteNextByte
	movlw .117
	call WriteNextByte
	movlw .136
	call WriteNextByte
	movlw .64
	call WriteNextByte
	movlw .117
	call WriteNextByte
	movlw .135
	call WriteNextByte
	movlw .128
	call WriteNextByte
	movlw .117
	call WriteNextByte
	movlw .152
	call WriteNextByte
	movlw .80
	call WriteNextByte
	movlw .144
	call WriteNextByte
	movlw .1
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .32
	call WriteNextByte
	movlw .144
	call WriteNextByte
	movlw .38
	call WriteNextByte
	movlw .120
	call WriteNextByte
	movlw .2
	call WriteNextByte
	movlw .211
	call WriteNextByte
	movlw .48
	call WriteNextByte
	movlw .152
	call WriteNextByte
	movlw .253
	call WriteNextByte
	movlw .194
	call WriteNextByte
	movlw .152
	call WriteNextByte
	movlw .229
	call WriteNextByte
	movlw .153
	call WriteNextByte
	movlw .64
	call WriteNextByte
	movlw .6
	call WriteNextByte
	movlw .240
	call WriteNextByte
	movlw .224
	call WriteNextByte
	movlw .163
	call WriteNextByte
	movlw .2
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .49
	call WriteNextByte
	movlw .246
	call WriteNextByte
	movlw .216
	call WriteNextByte
	movlw .1
	call WriteNextByte
	movlw .195
	call WriteNextByte
	movlw .245
	call WriteNextByte
	movlw .153
	call WriteNextByte
	movlw .48
	call WriteNextByte
	movlw .153
	call WriteNextByte
	movlw .253
	call WriteNextByte
	movlw .194
	call WriteNextByte
	movlw .153
	call WriteNextByte
	movlw .64
	call WriteNextByte
	movlw .228
	call WriteNextByte
	movlw .218
	call WriteNextByte
	movlw .226
	call WriteNextByte
	movlw .217
	call WriteNextByte
	movlw .224
	call WriteNextByte
	movlw .2
	call WriteNextByte
	movlw .1
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .120
	call WriteNextByte
	movlw .17
	call WriteNextByte
	movlw .8
	call WriteNextByte
	movlw .118
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .8
	call WriteNextByte
	movlw .118
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .8
	call WriteNextByte
	movlw .118
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .8
	call WriteNextByte
	movlw .118
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .8
	call WriteNextByte
	movlw .118
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .8
	call WriteNextByte
	movlw .118
	call WriteNextByte
	movlw .1
	call WriteNextByte
	movlw .8
	call WriteNextByte
	movlw .118
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .8
	call WriteNextByte
	movlw .118
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .18
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .97
	call WriteNextByte
	movlw .2
	call WriteNextByte
	movlw .1
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .24
	call WriteNextByte
	movlw .134
	call WriteNextByte
	movlw .4
	call WriteNextByte
	movlw .24
	call WriteNextByte
	movlw .134
	call WriteNextByte
	movlw .131
	call WriteNextByte
	movlw .24
	call WriteNextByte
	movlw .134
	call WriteNextByte
	movlw .130
	call WriteNextByte
	movlw .24
	call WriteNextByte
	movlw .134
	call WriteNextByte
	movlw .2
	call WriteNextByte
	movlw .24
	call WriteNextByte
	movlw .134
	call WriteNextByte
	movlw .1
	call WriteNextByte
	movlw .24
	call WriteNextByte
	movlw .24
	call WriteNextByte
	movlw .192
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .134
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .116
	call WriteNextByte
	movlw .3
	call WriteNextByte
	movlw .18
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .147
	call WriteNextByte
	movlw .18
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .181
	call WriteNextByte
	movlw .240
	call WriteNextByte
	movlw .163
	call WriteNextByte
	movlw .220
	call WriteNextByte
	movlw .249
	call WriteNextByte
	movlw .210
	call WriteNextByte
	movlw .151
	call WriteNextByte
	movlw .208
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .24
	call WriteNextByte
	movlw .34
	call WriteNextByte
	movlw .116
	call WriteNextByte
	movlw .3
	call WriteNextByte
	movlw .18
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .147
	call WriteNextByte
	movlw .18
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .181
	call WriteNextByte
	movlw .210
	call WriteNextByte
	movlw .151
	call WriteNextByte
	movlw .34
	call WriteNextByte
	movlw .194
	call WriteNextByte
	movlw .151
	call WriteNextByte
	movlw .18
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .165
	call WriteNextByte
	movlw .234
	call WriteNextByte
	movlw .18
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .165
	call WriteNextByte
	movlw .233
	call WriteNextByte
	movlw .18
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .165
	call WriteNextByte
	movlw .232
	call WriteNextByte
	movlw .18
	call WriteNextByte
	movlw .0
	call WriteNextByte
	movlw .165
	call WriteNextByte
	movlw .34
	call WriteNextByte
	movlw .192
	call WriteNextByte
	movlw .7
	call WriteNextByte
	movlw .127
	call WriteNextByte
	movlw .8
	call WriteNextByte
	movlw .51
	call WriteNextByte
	movlw .146
	call WriteNextByte
	movlw .149
	call WriteNextByte
	movlw .210
	call WriteNextByte
	movlw .150
	call WriteNextByte
	movlw .194
	call WriteNextByte
	movlw .150
	call WriteNextByte
	movlw .223
	call WriteNextByte
	movlw .247
	call WriteNextByte
	movlw .208
	call WriteNextByte
	movlw .7
	call WriteNextByte
	movlw .34
	call WriteNextByte
	movlw .192
	call WriteNextByte
	movlw .7
	call WriteNextByte
	movlw .127
	call WriteNextByte
	movlw .8
	call WriteNextByte
	movlw .210
	call WriteNextByte
	movlw .150
	call WriteNextByte
	movlw .162
	call WriteNextByte
	movlw .148
	call WriteNextByte
	movlw .51
	call WriteNextByte
	movlw .194
	call WriteNextByte
	movlw .150
	call WriteNextByte
	movlw .223
	call WriteNextByte
	movlw .247
	call WriteNextByte
	movlw .208
	call WriteNextByte
	movlw .7
	call WriteNextByte
	movlw .34
	call WriteNextByte

	call Start8051

DoneLoop
	goto DoneLoop

Start8051
	bsf STATUS,RP0
	movlw b'11111111'
	movwf TRISB
	bcf STATUS,RP0

	; Set the 8031 reset pin high - all other pins remain high impedance
	movlw b'11111101'
	movwf PORTA
	bsf STATUS,RP0
	movlw b'11111110'
	movwf TRISA
	bcf STATUS,RP0

	; Set the 8031 reset pin low - it should start executing the program!
	movlw b'11111110'
	movwf PORTA

	retlw 0

WriteNextByte
	movwf DataByte

	movf AddressByte,0
	movwf PORTB

	bsf STATUS,RP0
	clrf TRISB
	bcf STATUS,RP0

	; hi-address set to 0, DATA//PROG set low, 6116 /WR pin high, 8031 reset pin high, 74373 latch pin high
	movlw b'11100111'
	movwf PORTA
	
	; hi-address set to 0, DATA//PROG set low,6116 /WR pin high, 8031 reset pin high, 74373 latch pin low
	movlw b'11100101'
	movwf PORTA

	movf DataByte,0
	movwf PORTB

	; hi-address set to 0, DATA//PROG set low,6116 /WR pin low, 8031 reset pin high, 74373 latch pin low
	movlw b'11100001'
	movwf PORTA

	; hi-address set to 0, DATA//PROG set low,6116 /WR pin high, 8031 reset pin high, 74373 latch pin low
	movlw b'11100101'
	movwf PORTA

	bsf STATUS,RP0
	movlw b'11111111'
	movwf TRISB
	bcf STATUS,RP0

	incf AddressByte,1

	retlw 0

	end