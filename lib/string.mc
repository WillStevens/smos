; On entry the stack contains a pointer to a character string.
; On return the stack contains the length of the string (signed integer).

func StrLen
	dup

	while dup @8
		++

	swap -

; On entry the stack contains two pointers.
; The character string pointed two by the top-most pointer is copied to the character string
; pointed to by the bottom-most pointer.
; No return value.

func StrCpy
	var int dest

	swap >dest

	while dup @8 dup
		dest swap =8
		dest ++ >dest
		++

	pop pop dest 0 =8

; On entry the stack contains two pointers and a value n
; The character string pointed two by the top-most pointer is copied to the character string
; pointed to by the bottom-most pointer. At most n-1 characters are copied.
; The destination string is always terminated with a zero.
;
; Returns a pointer to the address of the null character in the destination string.
	
func StrNCpy0
	var int n
	var int dest
	
	>n
	
	swap >dest
	
	while dup @8 dup
		n -- dup >n
		if n !
			break
		dest swap =8
		dest ++ >dest
		++
	
	pop pop dest dup 0 =8
	

; On entry the stack contains two pointers to strings, str1 and str2.
; This function compares the strings pointed to by the two pointers
; On return the stack contains an integer 
; <0 if the first character that doesn't match has a lower value in str1
; 0 if the strings are identical
; >0 if the first character that doesn't match has a lower value in str2

func StrCmp
	var int str1
	var int str2
	>str2
	>str1

	while str1 @8 str2 @8 && str1 @8 str2 @8 == && 
		str1 ++ >str1
		str2 ++ >str2

	str1 @8 str2 @8 -

; Parameters
;  pointer to string

func PutString
	while dup @8 dup
		PutChar
		++
	pop pop

; Parameters
;  pointer to destination

func GetString
	while dup GetChar dup dup 10 == ! swap -1 == ! &&
		=8
		++

	pop pop 0 =8

func GetStringEcho
	while dup GetChar dup dup 10 == ! swap -1 == ! &&
		dup PutChar
		=8
		++

	pop pop 0 =8
	
func NewLine
	10 PutChar
	
func Dec2Hex
	dup
	if 10 <
		'0' +
	else
		55 +

func ShowHex2
	dup 240 & >> >> >> >> Dec2Hex PutChar 15 & Dec2Hex PutChar

func ShowHex4
	dup 0xff00 & >> >> >> >> >> >> >> >> ShowHex2 0xff & ShowHex2

func IsSpace
	var char c
	>c
	
	c 32 == c 8 == c 10 == || ||
	
func IsDigit
	var char c
	>c
	
	c '0' >= c '9' <= &&

func IsHexDigit
	var char c
	>c

	c '0' >= c '9' <= && c 'A' >= c 'F' <= && ||

func IsAlpha
	var char c
	32 | >c
	
	c 'a' >= c 'z' <= &&
	
func Hex2Dec
	dup
	if 'A' <
		'0' -
	else
		55 -

; Parse an N digit hex number
; Parameters
;   pointer to string
;   number of digits to parse
; Returns
;   0 if not successful
;  otherwise
;   the value
;   the pointer to the char after the last one parsed
;   1

func ParseHexN
	var int i
	var int r
	>i
	0 >r

	while i
		dup

		if @8 dup IsHexDigit
			Hex2Dec r << << << << + >r
			++
			i -- >i
		else
			pop pop
			break

	if i
		pop 0
	else
		r swap 1

func ParseHex4
	4 ParseHexN

func ParseHex2
	2 ParseHexN
