; Console emulation on 256 by 256 pixel display

; Best way to initialise font memory is to have a font object file that shell simply loads when it runs
var array 760 char font

var char con_x
var char con_y

var char origin_y

func ConLineFeed
	con_y ++ dup >con_y
	if 32 ==
		31 >con_y
		ConScroll

func ConPutChar
	if dup 32 >= dup 126 <= &&
		32 - 8 * &font + 8 con_y origin_y + 8 * con_x 8 * DisplayWrite
		con_x ++ >con_x
		if con_x 31 ==
			1 >con_x
			ConLineFeed
	elsif dup 13 ==
		; Carriage return
		pop
		1 >con_x
	elsif 10 ==
		; Line feed is used as the newline character, so perform a carriage return and line feed
		1 >con_x
		ConLineFeed
	else
		pop

func ConGetChar
	WaitKey

func ConLocate
	>con_y
	>con_x

func ConScroll
	var int x
	
	origin_y ++ dup >origin_y 8 * 0 DisplayOrigin

	; Write a blank line
	
	0 >x
	while x 256 <
		&font 8 31 origin_y + 8 * x DisplayWrite
		x 8 + >x
  