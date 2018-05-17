/*
 * macros.inc
 *
 *  Created: 14/05/2018 13:52:54
 *   Author: Johan Laptop
 */ 
 .MACRO MOD			; mod(@0,@1) -> mod(7,4) = 3
	PUSH @0			; Save current value
	subtract:
		SUB @0, @1
		BRGE subtract
	ADD @0,@1
	MOV tempRegister,@0
	POP @0
.ENDMACRO





//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

/*.MACRO addw
		push R26
		add @0,@1
		LDI R26,0
		ADC @2,R26
		pop
.ENDMACRO

; Modulo operator
.MACRO MOD			; mod(@0,@1) -> mod(7,4) = 3
	subtract:
		SUB @0, @1
		BRGE subtract
	ADD @0,@1
.ENDMACRO



//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%*/


