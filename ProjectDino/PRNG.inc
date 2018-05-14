/*
 * PRNG.inc
 *
 *  Created: 12/05/2018 16:15:18
 *  Authors: Johan Jacobs & Remco Royen
 */ 

 random:
	PUSH tempregister
	PUSH counter

	LDI counter,5

	nextbit:
		DEC counter
		BREQ randomFinished


		LSR randomNumber
		RJMP nextbit

	randomFinished:
	POP counter
	POP tempregister
	RET
