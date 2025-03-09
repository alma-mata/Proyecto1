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
// Variables globales (Registros)
.def	SALIDA7 = R16
.def	out_PORTD = R17
.def	CONTADOR7 = R18
.def	ciclo_hora = R19
.def	out_PORTB = R20
.def	minu_U = R21
.def	minu_D = R22
.def	hour_U = R23
.def	hour_D = R24
.def	puntos_LED = R25

// Variables SRAM

// Codigo FLASH
.cseg
.org	0x0000
	RJMP	SETUP
.org	OVF1addr
	RJMP	TIMER1_ISR
.org	OVF0addr
	RJMP TIMER0_ISR

//--------- Tablas ---------
// Tabla de valores del display de 7 segmentos
Tabla7seg: .db 0x40, 0x79, 0x24, 0x30, 0x19, 0x12, 0x02, 0x78, 0x00, 0x10

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
/*	LDI		R16, 0x00
	OUT		DDRC, R16				// Activa al PORTC como entrada
	LDI		R16, (1 << PC0) | (1 << PC1)
	OUT		PORTC, R16				// Habilita pull-ups*/
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

	//Inicializacion de variables
	LDI		out_PORTB, 0x01
	LDI		puntos_LED, 0x80
	CLR		ciclo_hora
	LDI		minu_U, 0x09
	LDI		minu_D, 0x05
	LDI		hour_U, 0x09
	LDI		hour_D, 0x01

	SEI

//****************************************
//				LOOP INFINITO
//****************************************
MAIN:
	RJMP	MAIN
//****************************************
//				SUB-RUTINAS
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
	ANDI	out_PORTD, 0x80

	SBRC	out_PORTB, 0				// Escoge salida de unidades o decenas
	MOV		CONTADOR7, minu_U			// Copia valor en la salida del contador
	SBRC	out_PORTB, 1
	MOV		CONTADOR7, minu_D
	SBRC	out_PORTB, 2
	MOV		CONTADOR7, hour_U
	SBRC	out_PORTB, 3
	MOV		CONTADOR7, hour_D

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
	CPI		ciclo_hora, 1
	BRNE	FIN_TIMER1
	CLR		ciclo_hora
	INC		minu_U
	CPI		minu_U, 0x0A
	BRNE	FIN_TIMER1
	CLR		minu_U
	INC		minu_D
	CPI		minu_D, 0x06
	BRNE	FIN_TIMER1
	CLR		minu_D
	INC		hour_U
	CPI		hour_D, 0x02
	BRNE	CONTINUAR_TIMER1_ISR
	CPI		hour_U, 0x04
	BRNE	CONTINUAR_TIMER1_ISR
	CLR		hour_U
	CLR		hour_D
	RJMP	FIN_TIMER1
CONTINUAR_TIMER1_ISR:
	CPI		hour_U, 0x0A
	BRNE	FIN_TIMER1
	CLR		hour_U
	INC		hour_D

FIN_TIMER1:
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