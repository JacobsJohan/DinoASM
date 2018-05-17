/*
 * keyboard.inc
 *
 *  Created: 2/05/2018 17:07:28
 *   Author: Johan Jacobs & Remco Royen
 */ 

 /* Registers R16, R17 and R18 are used in this function together with xpos (=R24) and ypos (=R25)*/
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

	LDI R18, 0b10001000				; Evaluate button 7: 1000 1000
	CP R16, R18
	BREQ button7

	LDI R18, 0b10000001				; Evaluate button A: 1000 0001
	CP R16, R18
	BREQ buttonA

	LDI R18, 0b10000010				; Evaluate button 1: 1000 0010
	CP R16, R18
	BREQ button1
	RJMP checkKeyboardRet

	button7:
		CPI dinoJumping,0
		BRNE checkKeyboardRet
		INC keyboardPressed
		LDI dinoJumping,4
		;rcall dinoJump
		RJMP checkKeyboardRet

	buttonA:
		CPI dinoJumping,0
		BRNE checkKeyboardRet
		//LDS randomNumber,TCNT0 // THERE IS SOMETHING WRONG WITH THE SEED
		//LDI randomNumber, 26
		CLR gameState
		RJMP checkKeyboardRet

	button1:
		CPI dinoJumping,0
		BRNE checkKeyboardRet
		INC dinoJumping
		RCALL addCactus
		RJMP checkKeyboardRet

	nothingPressed:
		CLR keyboardPressed
		;CPI dinoJumping, 127			; Check if dino has landed
		;BRLO checkKeyboardRet
		;CLR dinoJumping				; Only reset this register if the key has been released

	checkKeyboardRet:
		pop R18
		pop R17
		pop R16
		ret

/*dinoJumpold:
	push ypos
	push tempRegister
	push XH
	push XL

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


	dinoJumpRet:
		pop XL
		pop XH
		pop tempRegister
		pop ypos
		ret*/


/* Keyboard layout for evaluation */

/* Button 7: 1000 1000 | Button 8: 0100 1000 | Button 9: 0010 1000 | Button F: 0001 1000 */
/* Button 4: 1000 0100 | Button 5: 0100 0100 | Button 6: 0010 0100 | Button E: 0001 0100 */
/* Button 1: 1000 0010 | Button 2: 0100 0010 | Button 3: 0010 0010 | Button D: 0001 0010 */
/* Button A: 1000 0001 | Button 0: 0100 0001 | Button B: 0010 0001 | Button C: 0001 0001 */