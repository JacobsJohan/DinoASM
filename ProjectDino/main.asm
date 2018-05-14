;
; The dinosaur game
;
; Created: 28/04/2018 17:37:02
; Authors : Remco Royen & Johan Jacobs
;

// Y wordt niet gebruikt als pointer, toch? Mssch het ergens duidelijk bijschrijven want ik was ook effe in de war

.INCLUDE "m328pdef.inc"			; Load addresses of (I/O) registers

.def mulLSB = R0
.def mulMSB = R1

.def memoryByteRegister = R2

.def maxNmbrOfCacti = R3
.def nmbrOfCacti = R4

.def randomNumber = R5 // First iteration this is the seed, afterwards it is a pseudo-random number by use of LFSR

// Is there a more efficient way to do this?
.def randomSR1 = R6
.def randomSR2 = R7
.def randomSR3 = R8
.def randomSR4 = R9
.def randomSR5 = R10

.def normalOrExtreme = R11

.def counter = R16				; Register that serves for all kind of counter actions
.def illuminatedRow = R17		; Indicates the row that will be illuminated
.def tempRegister = R18			; Temporary register for short-time savings

.def waitingcounter0 = R19
.def waitingcounter1 = R20
.def keyboardPressed = R21
.def registerBitCounter = R22

.def gameState = R23 ; = 0x00 -> Playing
					 ; = 0xFF -> Wait for button to play

.def xpos = R24
.def ypos = R25


.equ bufferStartAddress = 0x0100
.equ cactusMemory = 0x0300
.equ dinoMemory = 0x0350
.equ speedMemory = 0x360

.equ maxValueCounter0 = 255;255
.equ maxValueCounter1 = 2;255
.equ maxValueCounter2 = 0;40

.ORG 0x0000
RJMP initOnlyOnce				; First instruction that is executed by the microcontroller

.ORG 0x0012
RJMP Timer2OverflowInterrupt

.ORG 0x001A
RJMP Timer1OverflowInterrupt

.ORG 0x0020
RJMP Timer0OverflowInterrupt


.include "keyboard.inc"
.include "drawings.inc"

////////////////////////////////////////////////////////////
//-------------------------INIT---------------------------//
////////////////////////////////////////////////////////////

initOnlyOnce:

	; Begin in idle state
	SER gameState
	RCALL clearScreen

	
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

	; No cacti drawn
	CLR nmbrOfCacti

	; First level only one cactus
	CLR maxNmbrOfCacti
	INC maxNmbrOfCacti
	INC maxNmbrOfCacti
	INC maxNmbrOfCacti

	CLR normalOrExtreme

	; Initialize dinosaur and draw first cactus
	rcall initDino
	rcall addCactus

	; Make sure keyboardPressed is zero
	CLR keyboardPressed

	////////////////////////////////////////////
	//- Timer1 (16 bit timer) initialisation -//
	////////////////////////////////////////////

	; Select normal counter mode
	LDI tempRegister, 0x0
	STS TCCR1A, tempRegister
	;set timer1 prescaler to 64 == 011, 1024 == 101 (Important: this is different for 8 bit timer)
	LDI tempRegister, 0x03
	STS TCCR1B,tempRegister

	/* Initial timer value will be 5 Hz. As the game progresses, the frequency at which the cacti move should be increased. We will do this by adding an immediate to the Y registers and storing this in TCNT1.  */
	; Prescaler 64: 65536 - 16 000 000/64/5 = 65536 - 50000 = 15536 => 00111100 10110000
	LDI YH, 0b00111100
	LDI YL, 0b10110000

	STS TCNT1H, YH
	STS TCNT1L, YL

	///////////////////////////////////////////
	//- Timer2 (8 bit timer) initialisation -//
	///////////////////////////////////////////

	; Select normal counter mode
	LDI tempRegister, 0x0
	STS TCCR2A, tempRegister
	;set timer2 prescaler to 1024 == 111, 
	LDI tempRegister, 0x07
	STS TCCR2B,tempRegister
	;set correct ‘reload values’ 256 - 16 000 000/1024/61 = 0 (after rounding)
	LDI tempRegister, 0
	STS TCNT2,tempRegister

	//////////////////////////
	//- Enable interrupts -//
	/////////////////////////

	SEI									; (SEI: global interrupt enable)
	LDI tempRegister, 1
	STS TIMSK1, tempRegister			; set peripheral interrupt flag
	STS TIMSK0, tempRegister
	STS TIMSK2, tempRegister
	RJMP main


Timer1OverflowInterrupt:
	push tempRegister
	IN tempRegister, SREG
	push tempRegister
	push counter //counter is here used as a temporary variable
	/* Reset timer values */
	STS TCNT1H, YH
	STS TCNT1L, YL

	/* Move the cactus */
	rcall moveCactus
	//RCALL newCactusOrNot

	mov tempregister,normalOrExtreme
	LDI counter,1
	AND normalOrExtreme,counter

	LSR tempregister
	CPI tempregister,100 ; After 100 mouvements the screen switches to extreme mode
	BREQ  modeSwitching
		INC tempregister
		LSL tempregister
		OR normalOrExtreme,tempregister
		RJMP timer1Ret

	modeSwitching:
		CLR tempregister
		INC tempregister
		EOR normalOrExtreme,tempregister

	timer1Ret:
		pop counter
		pop tempRegister
		OUT SREG, tempRegister
		pop tempRegister
		RETI

Timer0OverflowInterrupt:
	push XH
	push XL
	push tempRegister
	IN tempRegister, SREG
	push tempRegister

	/* Reset timer values */
	LDI tempRegister, 4
	OUT TCNT0,tempRegister		; TCNT0 = Timer/counter

	/*  Check if jump key was pressed. If it has been pressed, the dinosaur will move up, float, and move down. 
		Most of this could be written in a function call, but that would probably waste more time. Unfortunately 
		I don't see a less redundant way for all of the compare statements. */
	CPI keyboardPressed,1
	BRLO timer0Ret					; Branch if Lower

	; Move dino 1 pixel up
	INC keyboardPressed
	CPI keyboardPressed, 2
	BREQ dinoJump
	CPI keyboardPressed, 7
	BREQ dinoJump
	CPI keyboardPressed, 12
	BREQ dinoJump
	CPI keyboardPressed, 17
	BREQ dinoJump
	CPI keyboardPressed, 22
	BREQ dinoJump
	CPI keyboardPressed, 27
	BREQ dinoJump
	; Move dino 1 pixel down
	CPI keyboardPressed, 92
	BREQ dinoDrop
	CPI keyboardPressed, 97
	BREQ dinoDrop
	CPI keyboardPressed, 102
	BREQ dinoDrop
	CPI keyboardPressed, 107
	BREQ dinoDrop
	CPI keyboardPressed, 112
	BREQ dinoDrop
	CPI keyboardPressed, 117
	BREQ dinoDrop
	; reset keyboard pressed register
	CPI keyboardPressed, 118			
	BREQ preventOverflow
	RJMP timer0Ret						; Skip everything in other cases
	dinoJump:
		LDI XH, HIGH(dinoMemory)
		LDI XL, LOW(dinoMemory+1)		; The xposition of the dinosaur never changes, so we can just load the address of the y position and change that value
		LD tempRegister, X				; Load old ypos
		DEC tempRegister				; Decrease ypos (go up)
		ST X,tempRegister				; Store ypos
		RJMP timer0Ret

	dinoDrop:
		LDI XH, HIGH(dinoMemory)
		LDI XL, LOW(dinoMemory+1)		; The xposition of the dinosaur never changes, so we can just load the address of the y position and change that value
		LD tempRegister, X				; Load old ypos
		INC tempRegister				; Increase ypos (go down)
		ST X,tempRegister				; Store ypos
		RJMP timer0Ret

	preventOverflow:
		DEC keyboardPressed				; Make sure this is the same value in nothingPressed in keyboard.inc

	timer0Ret:
		pop tempRegister
		OUT SREG, tempRegister
		pop tempRegister
		pop XL
		pop XH
		RETI

	/* Timer2 is used to increase the speed of the cacti at a constant rate */
	Timer2OverflowInterrupt:
		PUSH tempRegister
		IN tempRegister, SREG
		PUSH tempRegister

		LDI tempRegister, 0
		STS TCNT2,tempRegister
		ADIW YL, 10

		POP tempRegister
		OUT SREG, tempRegister
		POP tempRegister
		RETI

////////////////////////////////////////////////////////////
//-------------------------MAIN---------------------------//
////////////////////////////////////////////////////////////

main:
	RCALL flushMemory
	RCALL clearScreen
	rcall drawDino
	rcall checkKeyboard

	CPI gameState,0
	BREQ playing
		RJMP init
	playing:
		rcall drawCactus
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
			RET
		notmax:
		;RCALL waitingLoop

		LDI counter,80
		columnbits:
			LD memoryByteRegister,-X ; -X = predec while X+ = postdec
			LDI registerBitCounter,8

			bitsOfRegister:
				SBRS normalOrExtreme,0
				RJMP normalMode
				extremeMode:
				SBRS memoryByteRegister,7
				RJMP pixelOn
				RJMP pixelOff

				normalMode:
				SBRC memoryByteRegister,7
				RJMP pixelOn

				; Pixel off
				pixelOff:
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

RET

waitingLoop:
	
	CLR waitingcounter0
	CLR waitingcounter1
	outerLoop:
		INC waitingcounter0
		CPI waitingcounter0,maxValueCounter0
		BRNE outerLoop

		middleLoop:
			CLR waitingcounter0
			INC waitingcounter1
			CPI waitingcounter1,maxValueCounter1
			BRNE outerLoop	
	finishLoop:
RET


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
RET
