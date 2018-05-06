/*
 * keyboard.inc
 *
 *  Created: 2/05/2018 17:07:28
 *   Author: Johan Laptop
 */ 
 checkKeyboard:
	push R16
	push R17
	push R18
	; Configure rows as inputs
	CBI DDRD,4
	SBI PORTD,4
	CBI DDRD,5
	SBI PORTD,5
	CBI DDRD,6
	SBI PORTD,6
	CBI DDRD,7
	SBI PORTD,7
	; Configure columns as outputs: outputs cannot have a pull-up resistor
	SBI DDRD,0
	SBI DDRD,1
	SBI DDRD,2
	SBI DDRD,3


	; Two step method
	; Set columns low (outputs): write zeros to outputs and check if we read something from input
	; CBI PORTD,4 --> this would turn off the pull up resistor at the input, which doesn't make sense
	CBI PORTD,0
	CBI PORTD,1
	CBI PORTD,2
	CBI PORTD,3
	; Read from rows (inputs)
	LDI R16,1			; Row counter

	SBIS PIND, 4
	RJMP readColumns
	LSL R16
	SBIS PIND, 5
	RJMP readColumns
	LSL R16
	SBIS PIND, 6
	RJMP readColumns
	LSL R16
	SBIS PIND, 7
	RJMP readColumns
	RJMP nothingPressed					; If nothing is pressed, return to rest of program



	readColumns:
	; Configure columns as inputs
	CBI DDRD,0
	SBI PORTD,0
	CBI DDRD,1
	SBI PORTD,1
	CBI DDRD,2
	SBI PORTD,2
	CBI DDRD,3
	SBI PORTD,3
	; Configure rows as outputs
	SBI DDRD,4
	SBI DDRD,5
	SBI DDRD,6
	SBI DDRD,7


	; Set rows low (outputs): write zeros to outputs and check if we read something from input
	CBI PORTD,4
	CBI PORTD,5
	CBI PORTD,6
	CBI PORTD,7

	; Read from columns (inputs)
	LDI R17,16			; Column counter

	SBIS PIND, 0
	RJMP evaluate
	LSL R17
	SBIS PIND, 1
	RJMP evaluate
	LSL R17
	SBIS PIND, 2
	RJMP evaluate
	LSL R17
	SBIS PIND, 3
	RJMP evaluate
	RJMP nothingPressed			; All columns are high so no button was pressed

	evaluate:
	ADD R16, R17

	LDI R18, 0x48				; Evaluate button 8: 0100 1000
	CP R16, R18
	BREQ button8
	RJMP checkKeyboardRet

	button8:
		CPI keyboardPressed,0
		BRNE checkKeyboardRet
		rcall dinoJump
		RJMP checkKeyboardRet


	/*
	LDI R18, 0x84				; Evaluate button 4: 1000 0100
	CP R16, R18
	BREQ button4

	LDI R18, 0x88				; Evaluate button 7: 1000 1000
	CP R16, R18
	BREQ button7



	
	turnOffLeds:
		SBI PORTC,2									; Output Vcc => upper LED turned off!
		SBI PORTC,3									; Output Vcc => lower LED is turned off!
		ret

	button4: 
	CBI PORTC,3
	RJMP checkKeyboard
	button8:
	CBI PORTC,2
	RJMP checkKeyboard
	button7:
	CBI PORTC,2
	CBI PORTC,3
	RJMP checkKeyboard*/

	nothingPressed:
		CPI keyboardPressed, 155			; Check if dino has landed
		BRLO checkKeyboardRet
		CLR keyboardPressed

	checkKeyboardRet:
		pop R18
		pop R17
		pop R16
		ret

dinoJump:
	; Turn on LED to test this
	;CBI PORTC,2									; Turn LED on
	push xpos
	push ypos
	push tempRegister
	push XH
	push XL


	;CPI keyboardPressed,1
	;BRSH dinoJumpRet								; If keyboard has been pressed and dino hasn't landed, skip rest of jump (Branch if Same or Higher)
	INC keyboardPressed

	LDI XH, HIGH(dinoMemory)
	LDI XL, LOW(dinoMemory)
		
	LDI xpos, 4							// xpos of dino
	ST X+, xpos
	LDI ypos, 2
	ST X+, ypos

	; Start timer to make dinosaur drop to the floor again

	dinoJumpRet:
		pop XL
		pop XH
		pop tempRegister
		pop ypos
		pop xpos
		ret