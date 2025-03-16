;-----------------------------------------------
; Universidad del Valle de Guatemala
; IE2023: Programacion de Microcontroladores
; Proyecto1.asm

; Autor: Alma Lisbeth Mata Ixcayau
; Proyecto: Proyecto 1, reloj digital
; Descripcion: Reloj digital que muestre la hora y fecha.
; Hardware: ATMEGA328P
; Creado: 04/03/2025
; Ultima modificacion: [pendiente]
;-----------------------------------------------

//****************************************
//				ENCABEZADO
//****************************************
.include "M328PDEF.inc"
// Variables globales (Constantes)
.equ	T0VALUE = 131
.equ	T1VALUEH = 0x0B
.equ	T1VALUEL = 0xDC		//0x0BDC = 3036
.equ	T2VALUE = 131
.equ	max_ciclosT1 = 1
// Variables globales (Registros)
.def	out_PORTD = R2
.def	in_PORTC = R3
.def	out_MODO = R4		// Salida para PC4 y PC5
.def	CONTADOR7 = R5
.def	SALIDA7 = R6
.def	max_dia = R7
.def	contador_dia = R8
.def	puntos_LED = R9
.def	constante_10 = R10

.def	variable1 = R16
.def	variable2 = R17
.def	estado = R18
.def	ciclo_hora = R19
.def	contador_mes = R20
.def	out_PORTB = R21
.def	bandera_ACCION = R22

// Variables SRAM
.dseg
.org	SRAM_START
minu_D:		.byte 1
minu_U:		.byte 1
hour_D:		.byte 1
hour_U:		.byte 1
dia_D:		.byte 1
dia_U:		.byte 1
mes_D:		.byte 1
mes_U:		.byte 1

// Codigo FLASH
.cseg
.org	0x0000
	RJMP	SETUP
.org	PCI1addr			// Pin Change Interrupt PORT C
	RJMP	PORTC_ISR
.org	OVF1addr
	RJMP	TIMER1_ISR
.org	OVF0addr
	RJMP TIMER0_ISR

//--------- Tablas ---------
// Tabla de valores del display de 7 segmentos
Tabla7seg:	.db 0x40, 0x79, 0x24, 0x30, 0x19, 0x12, 0x02, 0x78, 0x00, 0x10
Tabla_maxDIAS:	.db 0x1F, 0x1C, 0x1F, 0x1E, 0x1F, 0x1E, 0x1F, 0x1F, 0x1E, 0x1F, 0x1E, 0x1F
//****************************************
//				CONFIGURACION
//****************************************
SETUP:
	CLI
	// Configuración de la PILA
	LDI		R16, LOW(RAMEND)
	OUT		SPL, R16
	LDI		R16, HIGH(RAMEND)
	OUT		SPH, R16

	// Configuración del PRESCALER
	LDI		R16, (1 << CLKPCE)
	STS		CLKPR, R16				// Habilitar cambio de PRESCALER
	LDI		R16, (1 << CLKPS2)
	STS		CLKPR, R16				// Configurar Prescaler a 16 F_cpu = 1MHz

	CALL	INICIO_TIMERS

	// CONFIGURACIÓN DE ENTRADAS Y SALIDAS
	// Configuración PORT C como entrada con pull-up habilitado
	LDI		R16, 0xF0
	OUT		DDRC, R16				// Activa al PORTC como entrada
	LDI		R16, 0x0F
	OUT		PORTC, R16				// Habilita pull-ups
	// Configuración PORT B como salida inicialmente apagada
	LDI		R16, 0xFF
	OUT		DDRB, R16				// Activa los 4 bits menos significativos como salidas
	LDI		R16, 0x01
	OUT		PORTB, R16				// Deja encendido PB0
	// Configuración PORT D como salida inicialmente apagada
	LDI		R16, 0xFF
	OUT		DDRD, R16				// Activa los bits como salida
	LDI		R16, 0x02
	OUT		PORTD, R16				// Muestra "0" en el display
	// CONFIGURACION DE INTERRUPCIONES en los puertos
	LDI		R16, (1 << PCIE1)
    STS		PCICR, R16				// Habilita interrupciones en PORTC
    LDI		R16, 0x0F
    STS		PCMSK1, R16				// Habilita interrupciones en PC0 y PC1

	//Inicializacion de variables
	LDI		R16, 0x0A
	MOV		constante_10, R16
	LDI		R16, 0x80
	MOV		puntos_LED, R16
	CLR		ciclo_hora
	LDI		R16, 0x00
	STS		minu_U, R16
	STS		minu_D, R16
	STS		hour_U, R16
	STS		hour_D, R16
	LDI		estado, 0x01
	LDI		contador_mes, 0x00
	LDI		R16, 0x01
	MOV		contador_dia, R16

	CALL	NUEVO_MES
	SEI

//****************************************
//				LOOP INFINITO
//****************************************
MAIN:
	SBRC	bandera_ACCION, 0
	CALL	INC_HORA
	SBRC	bandera_ACCION, 1
	CALL	CAMBIO_DIA
	RJMP	MAIN

//****************************************
//			SUB-RUTINAS GENERALES
//****************************************
INC_HORA:
	CBR		bandera_ACCION, 1

	LDS		variable1, minu_U
	INC		variable1
	CPI		variable1, 0x0A
	BRNE	GUARDAR_MINU_U
	CLR		variable1
	STS		minu_U, variable1

	LDS		variable1, minu_D
	INC		variable1
	CPI		variable1, 0x06
	BRNE	GUARDAR_MINU_D
	CLR		variable1
	STS		minu_D, variable1

	LDS		variable1, hour_U
	LDS		variable2, hour_D
	INC		variable1
	CPI		variable2, 0x02
	BRNE	CONTINUAR_INC_HORA
	CPI		variable1, 0x04
	BRNE	CONTINUAR_INC_HORA
	CLR		variable1
	CLR		variable2
	STS		hour_U, variable1
	STS		hour_D, variable2
	SBR		bandera_ACCION, 0b00000010	// Bandera que activa el cambio de dia
	RJMP	FIN_INC_HORA
	CONTINUAR_INC_HORA:
		CPI		variable1, 0x0A
		BRNE	GUARDAR_HOUR
		CLR		variable1
		INC		variable2
		GUARDAR_HOUR:
			STS		hour_U, variable1
			STS		hour_D, variable2
			RJMP	FIN_INC_HORA
	GUARDAR_MINU_U:
		STS		minu_U, variable1
		RJMP	FIN_INC_HORA
	GUARDAR_MINU_D:
		STS		minu_D, variable1
		RJMP	FIN_INC_HORA
FIN_INC_HORA:	
	RET

CAMBIO_DIA:
	CBR		bandera_ACCION, 2

	CP		contador_dia, max_dia
	BREQ	NUEVO_MES
	INC		contador_dia

	LDS		variable1, dia_U
	INC		variable1
	CPI		variable1, 0x0A
	BRNE	GUARDAR_DIA_U
	CLR		variable1
	STS		dia_U, variable1
	LDS		variable1, dia_D
	INC		variable1
	STS		dia_D, variable1
	RET
	GUARDAR_DIA_U:
		STS		dia_U, variable1
		RET
NUEVO_MES:
	LDI		R16, 0x01
	MOV		contador_dia, R16
	LDI		variable1, 0x01
	STS		dia_U, variable1
	LDI		variable1, 0x00
	STS		dia_D, variable1

	CPI		contador_mes, 0x0C
	BRNE	CONTINUAR_NUEVO_MES
	CLR		contador_mes
	CONTINUAR_NUEVO_MES:
	LDI		ZH, HIGH(Tabla_maxDIAS<<1)	// Parte alta de Tabla7seg que esta en la Flash
	LDI		ZL, LOW(Tabla_maxDIAS<<1)	// Parte baja de la tabla
	ADD		ZL, contador_mes			// Suma el contador al puntero Z
	LPM		max_dia, Z					// Copia el valor del puntero

	INC		contador_mes
	CPI		contador_mes, 0x0A
	BREQ	GUARDAR_MES_D
	CPI		contador_mes, 0x0B
	BREQ	GUARDAR_MES_D
	CPI		contador_mes, 0x0C
	BRNE	GUARDAR_MES_U
	GUARDAR_MES_D:
		LDI		variable1, 0x01
		STS		mes_D, variable1 
		SUB 	contador_mes, constante_10
		STS		mes_U, contador_mes
		ADD		contador_mes, constante_10
		RET
	GUARDAR_MES_U:
		LDI		variable1, 0x00
		STS		mes_D, variable1
		STS		mes_U, contador_mes
		RET

MOSTRAR_HORA: 
	SBRC	out_PORTB, 0				// Escoge salida de unidades o decenas
	LDS		CONTADOR7, minu_U			// Copia valor en la salida del contador
	SBRC	out_PORTB, 1
	LDS		CONTADOR7, minu_D
	SBRC	out_PORTB, 2
	LDS		CONTADOR7, hour_U
	SBRC	out_PORTB, 3
	LDS		CONTADOR7, hour_D

	RET

MOSTRAR_FECHA: 
	SBRC	out_PORTB, 0				// Escoge salida de unidades o decenas
	LDS		CONTADOR7, mes_U			// Copia valor en la salida del contador
	SBRC	out_PORTB, 1
	LDS		CONTADOR7, mes_D
	SBRC	out_PORTB, 2
	LDS		CONTADOR7, dia_U
	SBRC	out_PORTB, 3
	LDS		CONTADOR7, dia_D

	RET

//****************************************
//		SUB-RUTINAS de INTERRUPCION
//****************************************
TIMER0_ISR:
	PUSH	R16
	IN		R16, SREG
	PUSH	R16
	
	IN		out_PORTB, PORTB
	LSL		out_PORTB
	CPI		out_PORTB, 0x10
	BRNE	SALIDA_PORTD
	LDI		out_PORTB, 0x01
SALIDA_PORTD:
	IN		out_PORTD, PORTD
	AND		out_PORTD, puntos_LED

	SBRC	estado, 0
	CALL	MOSTRAR_HORA
	SBRC	estado, 1
	CALL	MOSTRAR_FECHA	// Muestra la hora en el display

	LDI		ZH, HIGH(Tabla7seg<<1)	// Parte alta de Tabla7seg que esta en la Flash
	LDI		ZL, LOW(Tabla7seg<<1)	// Parte baja de la tabla
	ADD		ZL, CONTADOR7			// Suma el contador al puntero Z
	LPM		SALIDA7, Z				// Copia el valor del puntero
	OR		out_PORTD, SALIDA7
FIN_TIMER0:
	OUT		PORTB, out_PORTB
	OUT		PORTD, out_PORTD		// Muestra la salida en PORT D
	POP		R16
	OUT		SREG, R16
	POP		R16

	RETI

TIMER1_ISR:
	PUSH	R16
	IN		R16, SREG
	PUSH	R16
	// Parpadeo de LEDs
	IN		out_PORTD, PORTD
	EOR		out_PORTD, puntos_LED
	OUT		PORTD, out_PORTD
	// Incremento de HORA
	INC		ciclo_hora
	CPI		ciclo_hora, max_ciclosT1
	BRNE	FIN_TIMER1
	CLR		ciclo_hora
	SBR		bandera_ACCION, 0b00000001		// Activa el cambio de dia
FIN_TIMER1:
	POP		R16
	OUT		SREG, R16
	POP		R16

	RETI

PORTC_ISR:
	PUSH	R16
	IN		R16, SREG
	PUSH	R16

	IN		in_PORTC, PINC
	SBRS	in_PORTC, 2
	LSL		estado
	SBRS	in_PORTC, 3
	LSR		estado

	CPI		estado, 0x00
	BREQ	UNDERFLOW_ESTADO
	CPI		estado, 0x80
	BREQ	OVERFLOW_ESTADO
	RJMP	FIN_PORTC_ISR

	UNDERFLOW_ESTADO:
		LDI		estado, 0x40
		RJMP	FIN_PORTC_ISR
	OVERFLOW_ESTADO:
		LDI		estado, 0x01
		RJMP	FIN_PORTC_ISR
FIN_PORTC_ISR:
	POP		R16
	OUT		SREG, R16
	POP		R16

	RETI

INICIO_TIMERS:
	// INICIA TIMER 0
	LDI		R16, 0x00				// Configuración Modo Normal
	OUT		TCCR0A, R16
	LDI		R16, (1 << CS01)		// Prescaler = 8
	OUT		TCCR0B, R16
	LDI		R16, T0VALUE			// Valor inicial del Timer0
	OUT		TCNT0, R16

	// INICIA TIMER 1
	LDI		R16, 0x00				// Configuración Modo Normal
	STS		TCCR1A, R16
	LDI		R16, (1 << CS11)		// Prescaler = 8
	STS		TCCR1B, R16
	LDI		R16, T1VALUEH			// Valor inicial del Timer1
	LDI		R17, T1VALUEL			// Valor inicial del Timer1
	STS		TCNT1H, R16
	STS		TCNT1L, R17
	
	// HABILITAR INTERRUPCIONES POR OVERFLOW
	LDI		R16, (1 << TOIE0)			// Timer/counter0
	STS		TIMSK0, R16

	LDI		R16, (1 << TOIE1)			// Timer/counter1
	STS		TIMSK1, R16

	RET