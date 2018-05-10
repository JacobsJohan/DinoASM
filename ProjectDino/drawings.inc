/*
 * drawings.inc
 *
 *  Created: 2/05/2018 19:50:45
 *   Authors: Johan Jacobs & Remco Royen
 */ 
 drawPixel:

	PUSH xpos
	PUSH ypos

	PUSH counter
	PUSH tempregister

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
		
		LD xpos, X ; The old byte content is stored in xpos

		; Collision detect
		MOV counter,xpos ; Counter is used as a temp register
		AND counter,tempregister
		CPI counter,0
		BREQ noCollision
			SER gameState		// Comment this to turn off collision

		noCollision:
		; Draw updated field
		OR tempregister,xpos
		ST X+,tempregister	
	
	POP XL
	POP XH

	POP tempregister
	POP counter

	POP ypos
	POP xpos

RET


addCactus:
	push xpos
	push ypos

	PUSH tempregister

	push XH
	push XL

	LDI XH, HIGH(cactusMemory)			// Point to start of cactusMemory
	LDI XL, LOW(cactusMemory)

	MOV tempregister, nmbrOfCacti
	LSL tempregister

	ADD XL , tempregister

	LDI xpos, 38							// xpos of cactus
	ST X+, xpos
	LDI ypos, 10							// ypos of cactus
	ST X+, ypos

	INC nmbrOfCacti

	pop XL
	pop XH

	pop tempregister
	pop ypos
	pop xpos
	ret

drawCactus:
	push xpos
	push ypos
	push nmbrOfCacti

	push tempregister
	push XH
	push XL

	MOV tempregister,nmbrOfCacti

	// Assume that x and y postions of the first cactus to draw are saved in respectively the first byte at cactusMemory and the 2nd byte
	LDI XH, HIGH(cactusMemory) 
	LDI XL, LOW(cactusMemory)

	drawNextCactus:
		CPI tempregister,0
		BREQ noCactusLeft 
		DEC tempregister

	testing:
		LD xpos, X+
		LD ypos, X+	

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


	noCactusLeft:	
		pop XL
		pop XH
		pop tempregister
		pop nmbrOfCacti

		pop ypos
		pop xpos
		ret

moveCactus:
	push xpos
	push tempRegister
	push XH
	push XL

	mov tempregister, nmbrOfCacti

	LDI XH, HIGH(cactusMemory) 
	LDI XL, LOW(cactusMemory)

	moveNextCactus:
		CPI tempregister,0
		BREQ noCactiLeft
		DEC tempregister

		LD xpos, X
		DEC xpos			// Move cactus 1 xpos to the left
		BRNE store

		DEC nmbrOfCacti
		//RCALL deleteFirstCactus
		rcall addCactus
		INC XL
		INC XL
		RJMP moveNextCactus

	store:
		ST X, xpos

		INC XL
		INC XL
		RJMP moveNextCactus

	noCactiLeft:
		pop XL
		pop XH
		pop tempregister
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
	LD xpos, X+
	LD ypos, X

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

	LDI XH, HIGH(dinoMemory)			// Point to start of dinoMemory
	LDI XL, LOW(dinoMemory)

	LDI xpos, 4							// xpos of dino
	ST X+, xpos
	LDI ypos, 8
	ST X+, ypos

	pop XL
	pop XH
	pop ypos
	pop xpos
	ret

deleteFirstCactus:

	push xpos
	push tempregister
	PUSH nmbrOfCacti
	push XH
	push XL

	mov tempregister, nmbrOfCacti

	LDI XH, HIGH(cactusMemory) 
	LDI XL, LOW(cactusMemory)

	LSL tempregister

	stillDeleting:
		BREQ deletingDone
		ADIW XL,2
		LD tempregister,X
		DEC XL
		DEC XL
		ST X+,tempregister
		DEC tempregister
		RJMP stillDeleting


	deletingDone:
	pop XL
	pop XH
	pop nmbrOfCacti
	pop tempregister
	pop xpos
	
	ret