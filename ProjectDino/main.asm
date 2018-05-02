;
; Task9.asm
;
; Created: 28/04/2018 17:37:02
; Author : Remco Royen
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

.equ bufferStartAddress = 0x0100
.equ cactusMemory = 0x0300
.equ dinoMemory = 0x0350

.equ maxValueCounter0 = 255;255
.equ maxValueCounter1 = 1;255
.equ maxValueCounter2 = 0;40

.ORG 0x0000
RJMP init					; First instruction that is executed by the microcontroller

.ORG 0x001A
RJMP Timer1OverflowInterrupt

////////////////////////////////////////////////////////////
//-------------------------INIT---------------------------//
////////////////////////////////////////////////////////////

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

	LDI XH, HIGH(bufferStartAddress)
	LDI XL, LOW(bufferStartAddress)
	SBIW XL,10

	rcall initDino
	rcall addCactus
////////////////////////////////////////////
//- Timer1 (16 bit timer) initialisation -//
////////////////////////////////////////////

; Select normal counter mode
	LDI tempRegister, 0x0
	STS TCCR1A, tempRegister
	;set timer1 prescaler to 1024
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

////////////////////////////////////////////////////////////
//-------------------------MAIN---------------------------//
////////////////////////////////////////////////////////////

main:
	RCALL clearScreen

	/*
	LDI xpos,38
	LDI ypos,12
	RCALL drawPixel

	LDI xpos,37
	LDI ypos,12
	RCALL drawPixel*/

	rcall drawDino
	rcall drawCactus

	RCALL flushMemory
RJMP main


flushMemory:

	PUSH XH
	PUSH XL

	CLR illuminatedRow
	LDI XH, HIGH(bufferStartAddress)
	LDI XL, LOW(bufferStartAddress)
	SBIW XL,10

	nextRow:
		ADIW XL,20
		INC illuminatedRow
		CPI illuminatedRow,8
		BRNE notmax

			POP XL
			POP XH
			RETI
		notmax:
		;RCALL waitingLoop

		LDI counter,80
		columnbits:
			LD memoryByteRegister,-X ; -X = predec while X+ = postdec
			LDI registerBitCounter,8

			bitsOfRegister:
				SBRC memoryByteRegister,7
				RJMP pixelOn

				; Pixel off
				CBI PORTB,3
				RJMP administration
					
				; Pixel on
				pixelOn:
					SBI PORTB,3
				
				administration:	
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
					RJMP nextStep
	
				rowSet:
					SBI PORTB,3

				nextStep:
				SBI PORTB,5
				CBI PORTB,5
				DEC counter
				BREQ latching
				RJMP rowbits

		latching:
		SBI PORTB,4; Without waiting it also works (IF PROBLEM? LOOK AT THIS)
		RCALL waitingLoop
		CBI PORTB,4
		RJMP nextRow

RETI

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
RETI


clearScreen:
	push XH
	push XL

	LDI XH,0x01
	CLR XL

	LDI counter,70
	CLR tempRegister
	clearingLoop:
		ST X+,tempRegister
		DEC counter
		BRNE clearingLoop

	POP XL
	POP XH
RETI


drawPixel:

	PUSH xpos
	PUSH ypos

	PUSH XH
	PUSH XL

	LDI XH, HIGH(bufferStartAddress)
	LDI XL, LOW(bufferStartAddress)

	CPI ypos,7
	BRLO UpperPartScreen

		SUBI ypos,7
		ADIW xpos, 40

	UpperPartScreen:

		LDI tempRegister,10
		MUL ypos,tempRegister
		ADD XL,mulLSB

		MOV tempRegister,xpos
		LSR tempregister
		LSR tempregister
		LSR tempregister
		ADD XL,tempregister
		
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
		
		LD xpos, X
		OR tempregister,xpos
		ST X+,tempregister	
	
	POP XL
	POP XH

	POP ypos
	POP xpos

RETI


addCactus:
	push xpos
	push ypos

	push XH
	push XL

	LDI XH, HIGH(cactusMemory)			// Point to start of cactusMemory
	LDI XL, LOW(cactusMemory)

	LDI xpos, 38							// xpos of cactus
	ST X+, xpos
	LDI ypos, 10							// ypos of cactus
	ST X+, ypos

	pop XL
	pop XH

	pop ypos
	pop xpos
	ret

drawCactus:
	push xpos
	push ypos

	push XH
	push XL

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
		pop XL
		pop XH
		pop ypos
		pop xpos
		ret

moveCactus:
	push xpos
	push XH
	push XL

	LDI XH, HIGH(cactusMemory) 
	LDI XL, LOW(cactusMemory)

	LD xpos, X
	DEC xpos			// Move cactus 1 xpos to the left
	;CPI xpos,1
	BRNE moveCactusRet
	LDI xpos, 38		// In case cactus will fall off of screen, redraw it at beginning (to test stuff)

	moveCactusRet:
		ST X, xpos
		pop XL
		pop XH
		pop xpos
		ret

drawDino:
	push xpos
	push ypos

	push XH
	push XL

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
	
	pop XL
	pop XH
	pop ypos
	pop xpos
	ret

initDino:
	push xpos
	push ypos
	push XH
	push XL

	LDI XH, HIGH(dinoMemory)			// Point to start of cactusMemory
	LDI XL, LOW(dinoMemory)

	LDI xpos, 4							// xpos of cactus
	ST X+, xpos
	LDI ypos, 8
	ST X+, ypos

	pop XL
	pop XH
	pop ypos
	pop xpos
	ret