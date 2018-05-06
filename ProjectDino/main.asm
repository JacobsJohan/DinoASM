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
;.def waitingcounter2 = R21
.def keyboardPressed = R21
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
.equ maxValueCounter1 = 2;255
.equ maxValueCounter2 = 0;40

.ORG 0x0000
RJMP init					; First instruction that is executed by the microcontroller

.ORG 0x001A
RJMP Timer1OverflowInterrupt

.ORG 0x0020
RJMP Timer0OverflowInterrupt

.include "keyboard.inc"
.include "drawings.inc"

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

	; Configure a LED as output (to test things)
	SBI DDRC,2					; Pin PC2 is an output 
	SBI PORTC,2					; Output Vcc => upper LED turned off!




	; Initialize dinosaur and draw first cactus
	rcall initDino
	rcall addCactus

	; Make sure keyboardPressed is zero
	CLR keyboardPressed


	; This is needed for ???
	LDI XH, HIGH(bufferStartAddress)
	LDI XL, LOW(bufferStartAddress)
	SBIW XL,10

////////////////////////////////////////////
//- Timer1 (16 bit timer) initialisation -//
////////////////////////////////////////////

; Select normal counter mode
	LDI tempRegister, 0x0
	STS TCCR1A, tempRegister
	;set timer1 prescaler to 1024
	LDI tempRegister, 0x05
	STS TCCR1B,tempRegister
	/* For 1 Hz */
	;set correct ‘reload values’ 65536 - 16 000 000/1024/1 = 65536 - 15625 = 49911 => MSB = 0b1100 0010 LSB = 0b1111 0111 
	/* For 5 Hz */
	;set correct ‘reload values’ 65536 - 16 000 000/1024/5 = 65536 - 3125 = 62411 => MSB = 0b1111 0011 LSB = 0b1100 1011
	;To do a 16-bit write, the high byte must be written before the low byte.
	//LDI tempRegister, 0b11000010
	LDI tempRegister, 0b11110011
	STS TCNT1H, tempRegister
	//LDI tempRegister, 0b11110111
	LDI tempRegister, 0b11001011
	STS TCNT1L, tempRegister

///////////////////////////////////////////
//- Timer0 (8 bit timer) initialisation -//
///////////////////////////////////////////

	; Select normal counter mode
	LDI tempRegister, 0x0
	OUT TCCR0A, tempRegister
	;set timer0 prescaler to 1024
	LDI tempRegister, 0x05
	OUT TCCR0B,tempRegister
	;set correct ‘reload values’ 256 - 16 000 000/1024/62 = 4 (after rounding)
	LDI tempRegister, 4
	OUT TCNT0,tempRegister		; TCNT0 = Timer/counter

//////////////////////////
//- Enable interrupts -//
/////////////////////////

	SEI									; (SEI: global interrupt enable)
	LDI tempRegister, 1
	STS TIMSK1, tempRegister			; set peripheral interrupt flag
	STS TIMSK0, tempRegister			; set peripheral interrupt flag
	

	RJMP main


Timer1OverflowInterrupt:
	push tempRegister
	IN tempRegister, SREG
	push tempRegister
	/* Reset timer values */
	//LDI tempRegister, 0b11000010		; 1 Hz
	LDI tempRegister, 0b11110011		; 5 Hz
	STS TCNT1H, tempRegister
	//LDI tempRegister, 0b11110111		; 1 Hz
	LDI tempRegister, 0b11001011		; 5 Hz
	STS TCNT1L, tempRegister

	/* Move the cactus */
	rcall moveCactus

	/* Check if keyboard was pressed. If it has been pressed, let dino stay up for 10s, then initialize it again at start location 
	CPI keyboardPressed,1
	BRLO timer1Ret					; Branch if Lower
	INC keyboardPressed
	CPI keyboardPressed,10
	BRNE timer1Ret
	rcall initDino*/

	timer1Ret:
		pop tempRegister
		OUT SREG, tempRegister
		pop tempRegister
		reti

Timer0OverflowInterrupt:
	push XH
	push XL
	push tempRegister
	IN tempRegister, SREG
	push tempRegister

	/* Reset timer values */
	LDI tempRegister, 4
	OUT TCNT0,tempRegister		; TCNT0 = Timer/counter

	/* Check if keyboard was pressed. If it has been pressed, let dino stay up for 10s, then initialize it again at start location */
	CPI keyboardPressed,1
	BRLO timer0Ret					; Branch if Lower
	
	INC keyboardPressed
	CPI keyboardPressed,155
	BRNE timer0LoadMax
	rcall initDino

	timer0LoadMax:
		CPI keyboardPressed, 156
		BRLO timer0Ret
		LDI keyboardPressed, 155	; Prevent overflows from happening. Overflows could cause the dino to jump up again, a few seconds after landing.

	timer0Ret:
		pop tempRegister
		OUT SREG, tempRegister
		pop tempRegister
		pop XL
		pop XH
		reti

////////////////////////////////////////////////////////////
//-------------------------MAIN---------------------------//
////////////////////////////////////////////////////////////

main:
	RCALL clearScreen
	rcall checkKeyboard
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
	CLR waitingcounter1
	outerLoop:
		INC waitingcounter0
		CPI waitingcounter0,maxValueCounter0
		BRNE outerLoop
		;CLR waitingcounter1

		middleLoop:
			CLR waitingcounter0
			INC waitingcounter1
			CPI waitingcounter1,maxValueCounter1
			BRNE outerLoop
			/* Inner loop will not work like this if you uncomment now
			CLR waitingcounter2
			innerLoop:
		
				CPI waitingcounter2,maxValueCounter2
				BREQ middleLoop
				INC waitingcounter2
				RJMP innerLoop*/
	
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
