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
// Variables globales (Registros)
.equ	T0VALUE = 131
.def	out_PORTB = R20
// Variables SRAM

// Codigo FLASH
.cseg
.org	0x0000
	RJMP	SETUP
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

	// INICIA TEMPORIZADOR
	LDI		R16, 0x00						// Configuración Modo Normal
	OUT		TCCR0A, R16
	LDI		R16, (1 << CS01)  // Prescaler = 64
	OUT		TCCR0B, R16
	LDI		R16, T0VALUE					// Valor inicial del Timer0
	OUT		TCNT0, R16
	// HABILITAR INTERRUPCIONES DEL TOV0
	LDI		R16, (1 << TOIE0)			// Habilita interrupciones por desbordamiento
	STS		TIMSK0, R16

	// CONFIGURACIÓN DE ENTRADAS Y SALIDAS
	// Configuración PORT C como entrada con pull-up habilitado
	LDI		R16, 0x00
	OUT		DDRC, R16				// Activa al PORTC como entrada
	LDI		R16, (1 << PC0) | (1 << PC1)
	OUT		PORTC, R16				// Habilita pull-ups
	// Configuración PORT B como salida inicialmente apagada
	LDI		R16, 0xFF
	OUT		DDRB, R16				// Activa los 4 bits menos significativos como salidas
	LDI		R16, 0x01
	OUT		PORTB, R16				// Deja encendido PB0
	// Configuración PORT D como salida inicialmente apagada
	LDI		R16, 0xFF
	OUT		DDRD, R16				// Activa los bits como salida
	LDI		R16, 0x90
	OUT		PORTD, R16				// Muestra "0" en el display

	//Inicializacion de variables
	LDI		out_PORTB, 0x01

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
	BRNE	FIN_TIMER0
	LDI		out_PORTB, 0x01
FIN_TIMER0:
	OUT		PORTB, out_PORTB
	POP		R16
	OUT		SREG, R16
	POP		R16

	RETI