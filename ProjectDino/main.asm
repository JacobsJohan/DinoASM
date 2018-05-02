;
; ProjectDino.asm
;
; Created: 28/04/2018 17:37:02
; Authors : Remco Royen & Johan Jacobs
;

.INCLUDE "m328pdef.inc"			; Load addresses of (I/O) registers

.def mulLSB = R0
.def mulMSB = R1

.def counter = R16				; Register that serves for all kind of counter actions
.def illuminatedRow = R17		; Indicates the row that will be illuminated
.def tempRegister = R18			; Temporary register for short-time savings

.def waitingcounter0 = R19
.def waitingcounter1 = R20
.def waitingcounter2 = R21
.def registerBitCounter = R22

.def memoryByteRegister = R23

.def xpos = R24
.def ypos = R25

;.def XL = R26
;.def XH = R27
;.def YL = R28
;.def YH = R29

.equ maxValueCounter0 = 255;255
.equ maxValueCounter1 = 3;255
.equ maxValueCounter2 = 0;40
.equ cactusMemory = 0x0400
.equ dinoMemory = 0x0450

.ORG 0x0000
RJMP init					; First instruction that is executed by the microcontroller
.ORG 0x001A
RJMP Timer1OverflowInterrupt

init:

	; Configure output pin PB3 (Data input screen)
	SBI DDRB,3					; Pin PB3 is an output
	CBI PORTB,3					; Output low => initial condition low!

	; Configure output pin PB4 (Screen latching and enable'ing)
	SBI DDRB,4					; Pin PB4 is an output
	CBI PORTB,4					; Output low => initial condition low!

	; Configure output pin PB5 (Clock Screen)
	SBI DDRB,5					; Pin PB5 is an output
	CBI PORTB,5					; Output low => initial condition low!

	LDI XH,0x01
	CLR XL
	LDI YH,0x01
	CLR YL

	RCALL clearScreen

	LDI xpos,38
	LDI ypos,12


	/* Added code from Johan */

	; Select normal counter mode
	LDI tempRegister, 0x0
	STS TCCR1A, tempRegister
	;set timer0 prescaler to 1024
	LDI tempRegister, 0x05
	STS TCCR1B,tempRegister
	;set correct ‘reload values’ 65536 - 16 000 000/65536/1 = 65292 => MSB = 0b1111 1111 LSB = 0b0000 1100 (after rounding)
	;To do a 16-bit write, the high byte must be written before the low byte.
	LDI tempRegister, 0b11100000
	STS TCNT1H, tempRegister
	LDI tempRegister, 0b10001100
	STS TCNT1L, tempRegister
	; Enable interrupts (SEI: global interrupt enable)
	SEI
	LDI tempRegister, 1
	STS TIMSK1, tempRegister			; set peripheral interrupt flag

	rcall initDino
	rcall drawDino

	rcall addCactus

	CLR tempRegister
	SBR tempRegister,0x01
	ST X+,tempRegister

	LDI XH,0x01
	CLR XL
	SBIW XH:XL,10
	RJMP main

Timer1OverflowInterrupt:
	IN tempRegister, SREG
	push tempRegister

	LDI tempRegister, 0b11100000
	STS TCNT1H, tempRegister
	LDI tempRegister, 0b10001100
	STS TCNT1L, tempRegister

	rcall moveCactus

	pop tempRegister
	OUT SREG, tempRegister
	reti

main:
	ADIW XH:XL,20
	INC illuminatedRow
	CPI illuminatedRow,8
	BRNE notmax
	;rcall moveCactus
	rcall clearScreen
	rcall drawDino
	rcall drawCactus
	LDI illuminatedRow,1 // Re-initialize
	LDI XH,0x01
	CLR XL
	ADIW XH:XL,10
	notmax:
	;RCALL waitingLoop
	;rcall clearScreen
	;rcall drawCactus
	
	LDI counter,80
	columnbits:
		LD memoryByteRegister,-X ; -X = predec while X+ = postdec
		LDI registerBitCounter,8

		bitsOfRegister:
			SBRC memoryByteRegister,7
			RJMP pixelOn

			; Pixel off
				CBI PORTB,3
				SBI PORTB,5
				CBI PORTB,5
				DEC counter
				BREQ rows
				DEC registerBitCounter
				BREQ columnbits
				LSL memoryByteRegister
				RJMP bitsOfRegister
			
			; Pixel on
			pixelOn:
				SBI PORTB,3
				SBI PORTB,5
				CBI PORTB,5
				DEC counter
				BREQ rows
				DEC registerBitCounter
				BREQ columnbits
				LSL memoryByteRegister
				RJMP bitsOfRegister		

		rows:
		LDI counter,8
		rowbits:

			CP counter, illuminatedRow
			BREQ rowSet

				CBI PORTB,3
				SBI PORTB,5
				CBI PORTB,5
				DEC counter
				BREQ latching
				RJMP rowbits

			rowSet:

				SBI PORTB,3
				SBI PORTB,5
				CBI PORTB,5
				DEC counter
				BREQ latching
				RJMP rowbits

	latching:
	SBI PORTB,4; Without waiting it also works (IF PROBLEM? LOOK AT THIS)
	RCALL waitingLoop
	/*
	LDI tempRegister, 255			; Loop for a while

	loop1:
		DEC tempRegister
		BRNE loop1*/

	CBI PORTB,4

	RJMP main



waitingLoop:
	
	CLR waitingcounter0
	outerLoop:
		CPI waitingcounter0,maxValueCounter0
		BREQ finishLoop
		INC waitingcounter0
		CLR waitingcounter1

		middleLoop:
			CPI waitingcounter1,maxValueCounter1
			BREQ outerLoop
			INC waitingcounter1
			CLR waitingcounter2

			innerLoop:
		
				CPI waitingcounter2,maxValueCounter2
				BREQ middleLoop
				INC waitingcounter2
				RJMP innerLoop
	
	finishLoop:
	reti

clearScreen:
	
	LDI counter,70
	CLR tempRegister
	clearingLoop:
		ST Y+,tempRegister
		DEC counter
		BRNE clearingLoop

	LDI YH,0x01
	CLR YL

	RETI

drawPixel:

	PUSH xpos
	PUSH ypos

	CPI ypos,7
	BRLO UpperPartScreen

		SUBI ypos,7
		ADIW xpos, 40

	UpperPartScreen:

		LDI tempRegister,10
		MUL ypos,tempRegister
		ADD YL,mulLSB

		MOV tempRegister,xpos
		LSR tempregister
		LSR tempregister
		LSR tempregister
		ADD YL,tempregister
		
		ANDI xpos, 0b00000111
		LDI counter,0
		LDI tempregister,1
		bitContent:
			CP xpos,counter
			BREQ bitFound
			LSL tempregister
			INC counter
			RJMP bitContent
		
		bitfound:
		
		LD xpos, Y
		OR tempregister,xpos
		ST Y+,tempregister	
	
		LDI YH,0x01
		CLR YL

	POP ypos
	POP xpos

	RETI


addCactus:
	push xpos
	push ypos

	LDI XH, HIGH(cactusMemory)			// Point to start of cactusMemory
	LDI XL, LOW(cactusMemory)

	LDI xpos, 38							// xpos of cactus
	ST X+, xpos
	LDI ypos, 10							// ypos of cactus
	ST X+, ypos

	pop ypos
	pop xpos
	ret

drawCactus:
	push xpos
	push ypos

	// Assume that x and y postions of the first cactus to draw are saved in respectively the first byte at cactusMemory and the 2nd byte
	LDI XH, HIGH(cactusMemory) 
	LDI XL, LOW(cactusMemory)
	LD xpos, X+						// R16 contains xpos
	LD ypos, X+						// R17 contains ypos

	drawNextCactus:
		rcall drawPixel
		inc ypos
		rcall drawPixel
		inc xpos
		rcall drawPixel
		dec xpos
		dec xpos
		rcall drawPixel
		inc xpos
		inc ypos
		rcall drawPixel
		inc ypos
		rcall drawPixel

		;LD xpos, X+
		;CPI xpos,0
		;BREQ drawCactusRet				// If xpos of next cactus to draw is zero, then return from function
		;LD ypos, X+
		;RJMP drawNextCactus


	drawCactusRet:
		pop ypos
		pop xpos
		ret

moveCactus:
	push xpos

	LDI XH, HIGH(cactusMemory) 
	LDI XL, LOW(cactusMemory)

	LD xpos, X
	DEC xpos			// Move cactus 1 xpos to the left
	;CPI xpos,1
	BRNE moveCactusRet
	LDI xpos, 38		// In case cactus will fall off of screen, redraw it at beginning (to test stuff)

	moveCactusRet:
		ST X, xpos
		pop xpos
		ret

drawDino:
	push xpos
	push ypos

	// Assume that x and y postions of the first cactus to draw are saved in respectively the first byte at cactusMemory and the 2nd byte
	LDI XH, HIGH(dinoMemory) 
	LDI XL, LOW(dinoMemory)
	LD xpos, X+						// R16 contains xpos
	LD ypos, X						// R17 contains ypos

	rcall drawPixel
	dec xpos
	rcall drawPixel
	inc ypos
	rcall drawPixel
	inc ypos
	rcall drawPixel
	inc xpos
	rcall drawPixel
	dec xpos
	inc ypos
	rcall drawPixel
	inc ypos
	rcall drawPixel
	inc ypos
	rcall drawPixel
	dec ypos
	dec ypos
	dec xpos
	rcall drawPixel
	dec ypos
	rcall drawPixel
	dec xpos
	rcall drawPixel
	inc ypos
	rcall drawPixel
	inc ypos
	rcall drawPixel
	inc ypos
	rcall drawPixel
	
	pop ypos
	pop xpos
	ret

initDino:
	push xpos
	push ypos

	LDI XH, HIGH(dinoMemory)			// Point to start of cactusMemory
	LDI XL, LOW(dinoMemory)

	LDI xpos, 4							// xpos of cactus
	ST X+, xpos
	LDI ypos, 8
	ST X+, ypos

	pop ypos
	pop xpos
	ret
