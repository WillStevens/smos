; Library for a simple flat file system

; The term 'sector' is used in the same sense that it is used in other file systems.
; This is not necessarily the same as the use of 'sector' in flash memory devices.

; Each sector is 256 bytes in length

; Volume size is specified as number of sectors (temporarily reduced for faster execution speed)
; define VOL_SIZE 0x2000
define VOL_SIZE 0x0400


; The start of each sector contains a header, containing a flag byte followed by an unsigned 16-bit integer.
; The meaning of the flag bits is given below.
; FINL_SEC works in the opposite sense - cleared for the final sector, set for non-final sectors
; DEL_SEC works in the opposite sense - cleared for a deleted sector

define FREE_SEC 0x80
define FRST_SEC 0x40
define FINL_SEC 0x20
define DEL_SEC  0x10

; When a sector (except the first) is initially allocated, it is marked as not free, not the first sector, not the final sector, not deleted
define INIT_SEC 0x3F
; When the first sector is allocated, it is marked as not free, the first sector, not the final sector, not deleted
define INIT_FST 0x7F

; flag byte is ANDed with FRST_MSK and compared with FRST_TST when looking for first sector of a file
define FRST_MSK 0xDF
define FRST_TST 0x5F

; The 16-bit unsigned integer contains the address of the next sector, except for the final sector, where it contains the
; offset of the last byte in the file

; The first sector also contains a 32-character file name (as a null terminated string) following this.

define SEC_HSZ   3
define FNAME_SZ 32

; Total size of header for first sector
define FRST_HSZ 35

; The first sector of the file system.
; (Sector 0 is the boot sector, sectors 1 to 32 contain the 8K boot program)
define FRST_FSC 33

; FH_UART is the file handle corresponding to the UART
; FH_CONS is the file handle corresponding to the console
; Regard anything greater than or equal to FH_MIN as a valid file handle
define FH_UART 1
define FH_CONS 2
define FH_MIN 3

; A file handle is a pointer to 4 integers in this order:
;   The flags for the sector (1 byte)
;   The next-sector / end-offset integer (2 bytes)
;   Offset within sector (1 byte)
;   Sector number (2 bytes)
;
; 8 file handles can be use at once

var array 24 int fhSpace
var char fhAlloc

var array 32 char buffer


; Parameters
;  sector number
; Return value
;  starting sector of next file starting on or after parameter
;  VOL_SIZE if no file found

func NextFile
	++
	while dup VOL_SIZE <
		dup 0 swap &buffer 1 ReadBytes
		if &buffer @8 FRST_MSK & FRST_TST ==
			break
		else
			++

; Return the sector number of the first file, or VOL_SIZE is none found
func FirstFile
	FRST_FSC 1 - NextFile

; Did first file or last file return VOL_SIZE ?
; (This function exists so that caller doesn't need to know about VOL_SIZE)
func NoFile
	VOL_SIZE ==

; Parameters
;  sector number
;  pointer to string to store filename

func FileName
	var int ptr

	>ptr

	SEC_HSZ swap ptr FNAME_SZ ReadBytes


; Parameters:
;  pointer to file name
;
; Return values:
;  sector number
;  -1 if file not found

func FindFile
	var int s

	FRST_FSC >s

	while s VOL_SIZE <
		0 s &buffer 1 ReadBytes
		if &buffer @8 FRST_MSK & FRST_TST ==
			SEC_HSZ s &buffer FNAME_SZ ReadBytes
			if dup &buffer StrCmp !
				break
		s ++ >s

	pop

	if s VOL_SIZE <
		s
	else
		-1

; Parameters
;  pointer to file name

func DeleteFile
	if FindFile dup -1 == !
		0 swap dup 0 swap
	
		&buffer 1 ReadBytes
	
		&buffer &buffer @8 DEL_SEC ^ =8
	
		&buffer 1 PageProgram
	else
		pop

; Get a file handle. Returns it on success, 0 on failure
func FileHandle
	var char b
	var int r

	&fhSpace >r
	1 >b

	while b
		if fhAlloc b &
			r 6 + >r
			b << >b
		else
			break

	if b
		fhAlloc b ^ >fhAlloc
		r
	else
		0

; Close a file - free the file handle
; Parameters: file handle
; No return value

func FCloseRead
	var char b

	if dup FH_MIN >=
		1 >b

		while b
			if dup &fhSpace ==
				fhAlloc b ^ >fhAlloc
				break
			else
				b << >b
				6 -

	pop

; Parameters:
;  pointer to file name
;
; Return values:
;  0 if not found
;  otherwise:
;    file handle


func FOpenRead
	var int s
	var int f

	FindFile >s

	if s -1 ==
		0
	else
		FileHandle >f

		0 s f 3 ReadBytes

		f 3 + FRST_HSZ =8
		f 4 + s =

		f

; Parameters
;    file handle
;
; Return values:
;    byte read (-1 if end of file)

func FReadByte
	var char final
	var int l
	var char o
	var int s
	var int f

	if dup FH_MIN >=
		dup dup dup dup >f

		@8 FINL_SEC & ! >final

		1 + @ >l
		3 + @8 >o
		4 + @ >s

		if o final ! o l <= || &&
			o s &buffer 1 ReadBytes
			&buffer @8

			o 1 + >o

			if o !
				if final !
					SEC_HSZ >o
					l >s

					f 4 + s =

					0 s f 3 ReadBytes

			f 3 + o =8
		else
			-1
	elsif FH_UART ==
		SerGetChar
	else
		ConGetChar

; Return values:
;   VOL_SIZE if error
;   otherwise
;     sector number of a free sector 

func FreeSector
	var int s

	FRST_SEC >s

	while s VOL_SIZE <
		0 s &buffer 1 ReadBytes
		if &buffer @8 FREE_SEC &
			break
		s ++ >s

	s

; Parameters:
;  pointer to file name
;
; Return values:
;  0 if error
;  otherwise:
;    file handle

func FOpenWrite
	var int s
	var int f

	FileHandle >f

	FreeSector >s

	; Write the flag byte to the sector
	; Leave the count as 0xFFFF
	; Write the filename to the sector

	&buffer INIT_FST =8
	&buffer 1 + 0xFFFF =
	&buffer 3 + swap StrCpy

	0 s &buffer FRST_HSZ PageProgram

	; Set the file handle contents...
	f INIT_FST =8
	f 1 + 0xFFFF =
	f 3 + FRST_HSZ 1 - =8
	f 4 + s =

	f

; Parameters:
;  file handle

func FCloseWrite
	var int f

	if dup FH_MIN >=
		>f

		; Mark it as the final sector and write the offset of the last byte

		&buffer f @8 FINL_SEC ^ =8
		&buffer 1 + f 3 + @8 =

		0 f 4 + @ &buffer 3 PageProgram

		; Free file handle (that's all that FCloseRead does, so reuse it)
		f FCloseRead
	else
		pop

; Parameters
;  file handle
;  byte to write

func FWriteByte
	var int f
	var char o
	var int s
	var char b
	
	>b

	>f

	if f FH_MIN >=
		&buffer 3 + b =8

		f 3 + @8 dup >o

		if 255 ==

			; Get a free sector and put it into s, also into the buffer
			&buffer FreeSector dup >s =

			; Set the next sector pointer to the new sector
			1 f 4 + @ &buffer 2 PageProgram

			&buffer INIT_SEC =8
			&buffer 1 + 0xFFFF =

			; Write the sector header and the byte into the new sector
			0 s &buffer 4 PageProgram

			; Update the file handle
			f INIT_SEC =8
			f 1 + 0xFFFF =
			f 3 + SEC_HSZ =8
			f 4 + s =
		else
			; Write the byte and increment the offset in the file handle
			o ++ dup f 4 + @ &buffer 3 + 1 PageProgram
			f 3 + swap =8
	elsif f FH_UART ==
		b SerPutChar
	else
		b ConPutChar

var int stdin
var int stdout

func PutChar
	stdout swap FWriteByte

func GetChar
	stdin FReadByte

func SetStdIn
	>stdin
	
func SetStdOut
	>stdout
