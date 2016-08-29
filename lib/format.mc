; Parameters:
;	integer to print
;	file handle
;
; TODO - need to test the effect of passing -32768 to this function - I think it will work okay
func FPrintInt
	var int i
	var int f

	>f

	if dup 0 <
		negate
		f '-' FWriteByte

	10000 >i

	while dup i < i 1 > &&
		i 10 / >i

	while i
		i moddiv '0' + f swap FWriteByte
		i 10 / >i
	pop

func PutInt
	stdout FPrintInt

func FPrintString
	var int f
	
	>f
	
	while dup @8 dup
		f swap FWriteByte
		++
	pop pop

func PrintString
	stdout FPrintString

; Formatted output to file
; <parameters> "<format string>" f FPrintF
;
; Format specifiers recognised:
;
; %d
; %s

func FPrintF
	var int f
	var int s
	var char c

	>f >s

	while s @8 dup >c
		if c '%' == !
			f c FWriteByte
		else
			s ++ >s
			s @8 >c

			if c 'd' ==
				f FPrintInt

			if c 's' ==
				f FPrintString

		s ++ >s

func PrintF
	stdout FPrintF

	