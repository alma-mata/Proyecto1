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
.equ	max_ciclosT1 = 1
// Variables globales (Registros)
.def	compare_BLINK = R2
.def	out_PORTD = R3
.def	in_PORTC = R4
.def	CONTADOR7 = R6
.def	SALIDA7 = R7
.def	max_dia = R8
.def	contador_dia = R9
.def	puntos_LED = R10
.def	bandera_BLINK = R11

.def	variable1 = R16
.def	variable2 = R17
.def	estado = R18
.def	ciclo_hora = R19
.def	contador_mes = R20
.def	out_PORTB = R21
.def	bandera_ACCION = R22
.def	ciclos_BLINK = R23
.def	out_ALARMA = R24		// Salida para buzzer y led modo

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
Aminu_D:	.byte 1
Aminu_U:	.byte 1
Ahour_D:	.byte 1
Ahour_U:	.byte 1

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
	// Configuración PORT C como entrada con pull-up habilitado
	LDI		R16, 0xF0
	OUT		DDRC, R16				// Activa al PORTC como entrada
	LDI		R16, 0x0F
	OUT		PORTC, R16				// Habilita pull-ups
	// CONFIGURACION DE INTERRUPCIONES en los puertos
	LDI		R16, (1 << PCIE1)
    STS		PCICR, R16				// Habilita interrupciones en PORTC
    LDI		R16, (1 << PCINT11) | (1 << PCINT10) | (1 << PCINT9) | (1 << PCINT8)
    STS		PCMSK1, R16				// Habilita interrupciones en PC0 y PC1
	//Inicializacion de variables
	LDI		R16, 0xFF
	MOV		compare_BLINK, R16
	LDI		R16, 0x80
	MOV		puntos_LED, R16
	CLR		ciclo_hora
	LDI		R16, 0x00
	STS		minu_U, R16
	STS		minu_D, R16
	STS		hour_U, R16
	STS		hour_D, R16
	STS		dia_U, R16
	STS		dia_D, R16
	STS		mes_U, R16
	STS		mes_D, R16
	STS		Aminu_U, R16
	STS		Aminu_D, R16
	STS		Ahour_U, R16
	STS		Ahour_D, R16
	LDI		estado, 0x01
	LDI		contador_mes, 0xFF
	LDI		R16, 0x01
	MOV		contador_dia, R16
	CLR		bandera_BLINK
	CLR		ciclos_BLINK
	CLR		out_ALARMA
	CLR		bandera_ACCION

	CALL	NUEVO_MES
	SEI

//****************************************
//				LOOP INFINITO
//****************************************
MAIN:
	CALL	SIGN_ESTADO			// Enciende el LED de modo
	SBRC	bandera_ACCION, 0	// Incremento automático de reloj
	CALL	INC_HORA
	SBRC	bandera_ACCION, 1	// Cambio automático de día
	CALL	CAMBIO_DIA
	SBRC	bandera_ACCION, 2	// Botón incremento activado
	CALL	INCREMENTO
	SBRC	bandera_ACCION, 3	// Botón decremento activado
	CALL	DECREMENTO
	SBRC	bandera_ACCION, 5	// Bandera para comparar alarma
	CALL	comparar_ALARMA
	RJMP	MAIN

//****************************************
//			SUB-RUTINAS GENERALES
//****************************************
SIGN_ESTADO:
	SBRC	estado, 0		// Se verifica en que modo se esta
	RJMP	estado_RELOJ
	SBRC	estado, 1
	RJMP	estado_FECHA
	SBRC	estado, 2
	RJMP	estado_RELOJ
	SBRC	estado, 3
	RJMP	estado_RELOJ
	SBRC	estado, 4
	RJMP	estado_FECHA
	SBRC	estado, 5
	RJMP	estado_FECHA
	SBRC	estado, 6
	RJMP	estado_ALARMA
	SBRC	estado, 7
	RJMP	estado_ALARMA
	CPI		estado, 0x00
	BREQ	estado_ALARMA_activa
	estado_RELOJ:
		SBI		PORTC, 4		// Enciendo PC4 y apaga PC5 y PB5
		CBI		PORTC, 5
		CLR		out_ALARMA
		RET
	estado_FECHA:
		CBI		PORTC, 4		// Enciendo PC5 y apaga PC4 y PB5
		SBI		PORTC, 5
		CLR		out_ALARMA
		RET
	estado_ALARMA:
		CBI		PORTC, 4		// Enciendo PB5 y apaga PC4 y PC5
		CBI		PORTC, 5
		LDI		out_ALARMA, 0b00100000
		RET
	estado_ALARMA_activa:  // Se enciende PB4 que es el buzzer
		CBI		PORTC, 4
		CBI		PORTC, 5
		LDI		out_ALARMA, 0b00110000	// Enciendo PB5 y apaga PC4 y PC5
		RET
// ---------------- LOGICA DE DECREMENTO ----------------
DECREMENTO_MINUTOS:
	LDS		variable1, minu_U
	CPI		variable1, 0x00		// Antes de decrementar, se verifica si es 0
	BRNE	SAVE_DEC_MINU		// Si no es 0 guarda el valor
	LDI		variable1, 0x09		// Si es 0, carga 9 en unidad
	STS		minu_U, variable1 
	LDS		variable1, minu_D
	CPI		variable1, 0x00		// Verifica si decena es 0
	BRNE	SAVE_DEC_MIND		// Si no, salta a guardar la decena
	LDI		variable1, 0x05		// Si es 0, carga 5 a decena
	STS		minu_D, variable1
	RET
	SAVE_DEC_MINU:
		DEC		variable1		// Decrementa y guarda
		STS		minu_U, variable1
		RET
	SAVE_DEC_MIND:
		DEC		variable1		// Decrementa y guarda
		STS		minu_D, variable1
		RET

DECREMENTO_HORAS:
	LDS		variable1, hour_U
	CPI		variable1, 0x00			// Verifica si unidad es 0
	BRNE	SAVE_DEC_HOURU			// Si no es, salta a guardar unidad
	LDI		variable1, 0x09			// Si es 0, carga 9 a unidad
	STS		hour_U, variable1
	LDS		variable1, hour_D
	CPI		variable1, 0x00			// Verifica si decena es 0
	BRNE	SAVE_DEC_HOURD			// Si no es, salta a guardar decena
	LDI		variable1, 0x02			// Si es 0, guarda 2 en decena y 3 en unidad
	STS		hour_D, variable1
	LDI		variable1, 0x03
	STS		hour_U, variable1
	RET
	SAVE_DEC_HOURU:
		DEC		variable1		// Decrementa y guarda
		STS		hour_U, variable1
		RET
	SAVE_DEC_HOURD:
		DEC		variable1		// Decrementa y guarda
		STS		hour_D, variable1
		RET

DECREMENTO:		// Segun el estado, llama al bloque correspondiente
	CBR		bandera_ACCION, 0b00001000	// Apaga bandera decremento
	CPI		estado, 0b00000100			// Si estado es conf_minutos
	BREQ	DECREMENTO_MINUTOS	
	CPI		estado, 0b00001000			// Si estado es conf_horas
	BREQ	DECREMENTO_HORAS
	CPI		estado, 0b00010000			// Si estado es conf_mes
	BREQ	DECREMENTO_MES
	CPI		estado, 0b00100000			// Si estado es conf_dia
	BREQ	DECREMENTO_DIAS
	CPI		estado, 0b01000000			// Si estado es conf_alarma minutos
	BREQ	DEC_ALARMA_MIN
	CPI		estado, 0b10000000			// Si estado es conf_alarma hora
	BREQ	DEC_ALARMA_HOUR
	RET

DEC_ALARMA_MIN:		// Salto a bloque (quedaban muy lejos)
	RJMP	DECREMENTO_ALARMA_MIN
DEC_ALARMA_HOUR:	// Salto a bloque (quedaban muy lejos)
	RJMP	DECREMENTO_ALARMA_HOUR

DECREMENTO_DIAS:
	MOV		variable1, contador_dia		// Copia contador_dia para usar CPI
	CPI		variable1, 0x01				// Verifica se contador_dia es 1
	BREQ	UNDERFLOW_DIA				// Si es así, hace underflow
	DEC		contador_dia				// De lo contrario, disminuye dia

	LDS		variable1, dia_U
	CPI		variable1, 0x00			// Verifica si la unidad es 0
	BRNE	SAVE_DEC_DIAU			// Si no es, guarda unidad
	LDI		variable1, 0x09			// Si es 0, guarda 9
	STS		dia_U, variable1
	LDS		variable1, dia_D
	DEC		variable1			// Decrementa decena y guarda
	STS		dia_D, variable1
	RET
	SAVE_DEC_DIAU:
		DEC		variable1		// Decrementa unidad y guarda
		STS		dia_U, variable1
		RET
	UNDERFLOW_DIA: // Dependiendo del max_dia se escoge el bloque
		MOV		contador_dia, max_dia // Copia max_dia en contador_dia
		MOV		variable1, max_dia
		CPI		variable1, 0x1F		// Mes de 31 dia
		BREQ	REINICIO_31DIAS
		CPI		variable1, 0x1E		// Mes de 30 dia
		BREQ	REINICIO_30DIAS
		CPI		variable1, 0x1C		// Mes de 28 dia
		BREQ	REINICIO_28DIAS
	REINICIO_31DIAS:  // Carga 3 y 1 a decena y unidad, y guarda
		LDI		variable1, 0x01
		STS		dia_U, variable1
		LDI		variable1, 0x03
		STS		dia_D, variable1
		RET
	REINICIO_30DIAS:	// Carga 3 y 0 a decena y unidad, y guarda
		LDI		variable1, 0x00
		STS		dia_U, variable1
		LDI		variable1, 0x03
		STS		dia_D, variable1
		RET
	REINICIO_28DIAS:	// Carga 2 y 8 a decena y unidad, y guarda
		LDI		variable1, 0x08
		STS		dia_U, variable1
		LDI		variable1, 0x02
		STS		dia_D, variable1
		RET

DECREMENTO_MES:
	LDI		R16, 0x01			// Reinicio de inicio de mes
	MOV		contador_dia, R16
	LDI		variable1, 0x01
	STS		dia_U, variable1
	LDI		variable1, 0x00
	STS		dia_D, variable1

	LDS		variable1, mes_U
	CPI		variable1, 0x01
	BRNE	CONTINUAR_DECREMENTO_MES
	LDS		variable2, mes_D
	CPI		variable2, 0x00
	BRNE	CONTINUAR_DECREMENTO_MES
	LDI		contador_mes, 0x0C
	LDI		variable1, 0x03
	LDI		variable2, 0x01
	STS		mes_D, variable2
	CONTINUAR_DECREMENTO_MES:
		CPI		contador_mes, 0x09
		BRNE	DEC_MES_U
		LDI		variable1, 0x09
		STS		mes_U, variable1
		LDI		variable1, 0x00
		STS		mes_D, variable1
		RJMP	MAXIMO_DIAS
	DEC_MES_U:
		DEC		variable1
		STS		mes_U, variable1
		RJMP	MAXIMO_DIAS
	MAXIMO_DIAS:
		DEC		contador_mes
		LDI		ZH, HIGH(Tabla_maxDIAS<<1)	// Parte alta de Tabla_maxDIAS que esta en la Flash
		LDI		ZL, LOW(Tabla_maxDIAS<<1)	// Parte baja de la tabla
		ADD		ZL, contador_mes			// Suma el contador al puntero Z
		LPM		max_dia, Z					// Copia el valor del puntero
		
		RET
// ---------------- LOGICA DE HORA ----------------
INC_HORA:
	CBR		bandera_ACCION, 0b00000001

	AUMENTO_MINUTOS:
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
	CPI		estado, 0b00000100
	BRNE	AUMENTO_HORA
	RET
	AUMENTO_HORA:
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
	SBRS	estado, 3
	SBR		bandera_ACCION, 0b00000010	// Bandera que activa el cambio de dia
	RET
	CONTINUAR_INC_HORA:
		CPI		variable1, 0x0A
		BRNE	GUARDAR_HOUR
		CLR		variable1
		INC		variable2
		GUARDAR_HOUR:
			STS		hour_U, variable1
			STS		hour_D, variable2
			RET
	GUARDAR_MINU_U:
		STS		minu_U, variable1
		RET
	GUARDAR_MINU_D:
		STS		minu_D, variable1
		RET

INCREMENTO:
	CBR		bandera_ACCION, 0b00000100 // Limpia bandera de incremento
	CPI		estado, 0b00000100		// Estado configuracion minutos
	BREQ	AUMENTO_MINUTOS
	CPI		estado, 0b00001000		// Estado configuracion horas
	BREQ	AUMENTO_HORA
	CPI		estado, 0b00010000		// Estado configuracion mes
	BREQ	NUEVO_MES
	CPI		estado, 0b00100000		// Estado configuracion dia
	BREQ	AUMENTO_DIA
	CPI		estado, 0b01000000		// Estado configuracion minutos alarma
	BREQ	INC_ALARMA_MIN
	CPI		estado, 0b10000000		// Estado configuracion horas alarma
	BREQ	INC_ALARMA_HOUR
	RET

INC_ALARMA_MIN:
	RJMP	AUMENTO_ALARMA_MIN
INC_ALARMA_HOUR:
	RJMP	AUMENTO_ALARMA_HOUR

// ---------------- LOGICA DE FECHA ----------------
CAMBIO_DIA:
	CBR		bandera_ACCION, 0b00000010
	AUMENTO_DIA:
	CP		contador_dia, max_dia	// Compara si llego al maximo de dias
	BREQ	NUEVO_MES				// Si es así, cambia de mes
	INC		contador_dia

	LDS		variable1, dia_U	// Incrementa unidades
	INC		variable1
	CPI		variable1, 0x0A		// Verifica si llegan a 10
	BRNE	GUARDAR_DIA_U		// Si no, solo guarda el valor
	CLR		variable1
	STS		dia_U, variable1	// Si sí, carga 0 a unidades e incrementa decenas
	LDS		variable1, dia_D
	INC		variable1
	STS		dia_D, variable1
	RET
	GUARDAR_DIA_U:
		STS		dia_U, variable1
		RET
NUEVO_MES:
	// Reinicio de inicio de mes
	LDI		R16, 0x01
	MOV		contador_dia, R16
	LDI		variable1, 0x01
	STS		dia_U, variable1
	LDI		variable1, 0x00
	STS		dia_D, variable1
	SBRC	estado, 5		// Si se esta en el estado 5, regresa
	RET

	INC		contador_mes	// Incrementa contador mes
	LDI		ZH, HIGH(Tabla_maxDIAS<<1)	// Parte alta de Tabla_maxDIAS que esta en la Flash
	LDI		ZL, LOW(Tabla_maxDIAS<<1)	// Parte baja de la tabla
	ADD		ZL, contador_mes			// Suma el contador al puntero Z
	LPM		max_dia, Z					// Carga maximo de dias
	
	LDS		variable1, mes_U
	CPI		variable1, 0x02			// Verifica si unidad es 2
	BRNE	CONTINUAR_GUARDADO_MES	// Si no, solo continua
	LDS		variable2, mes_D		// Si si, verifica si decena es 1
	CPI		variable2, 0x01
	BRNE	CONTINUAR_GUARDADO_MES // Si no, continua
	LDI		variable1, 0x00
	STS		mes_D, variable1	// Si si, hace overflow
	CLR		contador_mes
	CONTINUAR_GUARDADO_MES:
		CPI		contador_mes, 0x09 // Si llega a 10, carga 0 y 1 en unidad y decena
		BRNE	GUARDAR_MES_U		// Si no, guarda la unidad
		LDI		variable1, 0x00
		STS		mes_U, variable1
		LDI		variable1, 0x01
		STS		mes_D, variable1
		RET
	GUARDAR_MES_U:
		INC		variable1
		STS		mes_U, variable1
		RET

// ---------------- LOGICA DE ALARMA ----------------
AUMENTO_ALARMA_MIN:		//Misma logica que inc minutos reloj
	LDS		variable1, Aminu_U
	INC		variable1
	CPI		variable1, 0x0A
	BRNE	GUARDAR_AMINU_U
	CLR		variable1
	STS		Aminu_U, variable1
	LDS		variable1, Aminu_D
	INC		variable1
	CPI		variable1, 0x06
	BRNE	GUARDAR_AMINU_D
	CLR		variable1
	STS		Aminu_D, variable1
	RET
	GUARDAR_AMINU_U:
		STS		Aminu_U, variable1
		RET
	GUARDAR_AMINU_D:
		STS		Aminu_D, variable1
		RET
AUMENTO_ALARMA_HOUR:	//Misma logica que inc horas reloj
	LDS		variable1, Ahour_U
	LDS		variable2, Ahour_D
	INC		variable1
	CPI		variable2, 0x02
	BRNE	CONTINUAR_INC_AHORA
	CPI		variable1, 0x04
	BRNE	CONTINUAR_INC_AHORA
	CLR		variable1
	CLR		variable2
	STS		Ahour_U, variable1
	STS		Ahour_D, variable2
	RET
	CONTINUAR_INC_AHORA:
		CPI		variable1, 0x0A
		BRNE	GUARDAR_AHOUR
		CLR		variable1
		INC		variable2
		GUARDAR_AHOUR:
			STS		Ahour_U, variable1
			STS		Ahour_D, variable2
			RET

DECREMENTO_ALARMA_MIN:	//Misma logica que dec minutos reloj
	LDS		variable1, Aminu_U
	CPI		variable1, 0x00
	BRNE	SAVE_DEC_AMINU
	LDI		variable1, 0x09
	STS		Aminu_U, variable1
	LDS		variable1, Aminu_D
	CPI		variable1, 0x00
	BRNE	SAVE_DEC_AMIND
	LDI		variable1, 0x05
	STS		Aminu_D, variable1
	RET
	SAVE_DEC_AMINU:
		DEC		variable1
		STS		Aminu_U, variable1
		RET
	SAVE_DEC_AMIND:
		DEC		variable1
		STS		Aminu_D, variable1
		RET

DECREMENTO_ALARMA_HOUR:  //Misma logica que dec horas reloj
	LDS		variable1, Ahour_U
	CPI		variable1, 0x00
	BRNE	SAVE_DEC_AHOURU
	LDI		variable1, 0x09
	STS		Ahour_U, variable1
	LDS		variable1, Ahour_D
	CPI		variable1, 0x00
	BRNE	SAVE_DEC_AHOURD
	LDI		variable1, 0x02
	STS		Ahour_D, variable1
	LDI		variable1, 0x03
	STS		Ahour_U, variable1
	RET
	SAVE_DEC_AHOURU:
		DEC		variable1
		STS		Ahour_U, variable1
		RET
	SAVE_DEC_AHOURD:
		DEC		variable1
		STS		Ahour_D, variable1
		RET

comparar_ALARMA:
	CBR		bandera_ACCION, 0b00100000
	LDS		variable1, minu_U
	LDS		variable2, Aminu_U
	CPSE	variable1, variable2	// Verifica si las unidades de minutos coinciden 
	RET			// De lo contrario regresa
	LDS		variable1, minu_D		
	LDS		variable2, Aminu_D
	CPSE	variable1, variable2	// Verifica si las decenas de minutos coinciden
	RET
	LDS		variable1, hour_U
	LDS		variable2, Ahour_U
	CPSE	variable1, variable2	// Verifica si las unidades de horas coinciden
	RET
	LDS		variable1, hour_D
	LDS		variable2, Ahour_D
	CPSE	variable1, variable2	// Verifica si las decenas de horas coinciden
	RET
	CLR		variable1			// Limpia variables de alarma
	STS		Aminu_U, variable1
	STS		Aminu_D, variable1
	STS		Ahour_U, variable1
	STS		Ahour_D, variable1
	SBR		out_ALARMA, 0b00010000	
	CBR		bandera_ACCION, 0b00010000	// Activa bandera alarma_activada
	CLR		estado						// Limpia estado para entrar a alarma_activada
	RET

// ---------------- LOGICA DE SALIDAS ----------------
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

MOSTRAR_ALARMA: 
	SBRC	out_PORTB, 0				// Escoge salida de unidades o decenas
	LDS		CONTADOR7, Aminu_U			// Copia valor en la salida del contador
	SBRC	out_PORTB, 1
	LDS		CONTADOR7, Aminu_D
	SBRC	out_PORTB, 2
	LDS		CONTADOR7, Ahour_U
	SBRC	out_PORTB, 3
	LDS		CONTADOR7, Ahour_D
	RET

//****************************************
//		SUB-RUTINAS de INTERRUPCION
//****************************************
TIMER0_ISR:
	PUSH	R16
	PUSH	R17
	IN		R16, SREG
	PUSH	R16
	// Multiplexado de PORTB
	IN		out_PORTB, PINB
	ANDI	out_PORTB, 0x0F
	LSL		out_PORTB
	CPI		out_PORTB, 0x10
	BRNE	SALIDA_PORTD
	LDI		out_PORTB, 0x01
SALIDA_PORTD:
	IN		out_PORTD, PORTD
	AND		out_PORTD, puntos_LED

	SBRC	estado, 0
	CALL	MOSTRAR_HORA	// Muestra la hora en el display
	SBRC	estado, 1
	CALL	MOSTRAR_FECHA	// Muestra la Fecha en el display
	SBRC	estado, 2
	CALL	MOSTRAR_HORA	// Muestra la hora en el display
	SBRC	estado, 3
	CALL	MOSTRAR_HORA	// Muestra la hora en el display
	SBRC	estado, 4
	CALL	MOSTRAR_FECHA	// Muestra la Fecha en el display
	SBRC	estado, 5
	CALL	MOSTRAR_FECHA	// Muestra la fecha en el display
	SBRC	estado, 6
	CALL	MOSTRAR_ALARMA	// Muestra la alarma en el display
	SBRC	estado, 7
	CALL	MOSTRAR_ALARMA	// Muestra la alarma en el display
	CPI		estado, 0x00
	BRNE	CONTINUAR_SALIDA
	CALL	MOSTRAR_HORA
	CONTINUAR_SALIDA:
	LDI		ZH, HIGH(Tabla7seg<<1)	// Parte alta de Tabla7seg que esta en la Flash
	LDI		ZL, LOW(Tabla7seg<<1)	// Parte baja de la tabla
	ADD		ZL, CONTADOR7			// Suma el contador al puntero Z
	LPM		SALIDA7, Z				// Copia el valor del puntero
	
	LDI		R16, 0x00
	CP		bandera_BLINK, R16	// Si bandera es 0, Apagar displays
	BRNE	FIN_TIMER0
	CPI		estado, 0b00000100	// En estado 3, 5, 7 parpadena display 1 y 2
	BREQ	APAGAR_DISPLAY12
	CPI		estado, 0b00001000	// En estado 4, 6, 8 parpadena display 3 y 4
	BREQ	APAGAR_DISPLAY34
	CPI		estado, 0b00010000
	BREQ	APAGAR_DISPLAY12
	CPI		estado, 0b00100000
	BREQ	APAGAR_DISPLAY34
	CPI		estado, 0b01000000
	BREQ	APAGAR_DISPLAY12
	CPI		estado, 0b10000000
	BREQ	APAGAR_DISPLAY34
	CPI		estado, 0x00
	BREQ	estado_00
	RJMP	FIN_TIMER0
	estado_00:	// En estado 0 parpadean todos los DISPLAYS
		CPI		out_PORTB, 0b00000001
		BREQ	APAGAR_DISPLAY12
		CPI		out_PORTB, 0b00000010
		BREQ	APAGAR_DISPLAY12
		CPI		out_PORTB, 0b00000100
		BREQ	APAGAR_DISPLAY34
		CPI		out_PORTB, 0b00001000
		BREQ	APAGAR_DISPLAY34
	APAGAR_DISPLAY12:	// Parpadeo de displays 0 y 1
		CPI		out_PORTB, 0b00000100	// Verifica que sean PB0 y PB1
		BREQ	FIN_TIMER0
		CPI		out_PORTB, 0b00001000
		BREQ	FIN_TIMER0
		LDI		R16, 0x7F		// Pone en 1 todos los pines de PORTD
		MOV		SALIDA7, R16
		RJMP	FIN_TIMER0
	APAGAR_DISPLAY34:	// Parpadeo de display 2 y 3
		CPI		out_PORTB, 0b00000001 // Verifica que sean PB0 y PB1
		BREQ	FIN_TIMER0
		CPI		out_PORTB, 0b00000010
		BREQ	FIN_TIMER0
		LDI		R16, 0x7F	// Pone en 1 todos los pines de PORTD
		MOV		SALIDA7, R16
		RJMP	FIN_TIMER0
FIN_TIMER0:
	OR		out_PORTB, out_ALARMA
	OR		out_PORTD, SALIDA7
	OUT		PORTB, out_PORTB
	OUT		PORTD, out_PORTD		// Muestra la salida en PORT D
	INC		ciclos_BLINK			// Parpadeo de displays
	CPI		ciclos_BLINK, 100		// Verifica si se cumple el ciclo
	BRNE	continuar_FIN_TIMER0
	CLR		ciclos_BLINK
	EOR		bandera_BLINK, compare_BLINK	// Hace XOR para apagar o encender la bandera
	continuar_FIN_TIMER0:
	POP		R16
	OUT		SREG, R16
	POP		R17
	POP		R16

	RETI

TIMER1_ISR:
	PUSH	R16
	PUSH	R17
	IN		R16, SREG
	PUSH	R16
	// Parpadeo de LEDs
	IN		out_PORTD, PIND
	EOR		out_PORTD, puntos_LED
	OUT		PORTD, out_PORTD
	
	CPI		estado, 0x00		// Incremento automático para estdo 0, 1, 2, 6 y 7
	BREQ	INCREMENTO_HORA
	CPI		estado, 0b00000001
	BREQ	INCREMENTO_HORA
	CPI		estado, 0b00000010
	BREQ	INCREMENTO_HORA
	CPI		estado, 0b01000000
	BREQ	INCREMENTO_HORA
	CPI		estado, 0b10000000
	BREQ	INCREMENTO_HORA
	RJMP	FIN_TIMER1
	INCREMENTO_HORA:		// Incremento de HORA
	INC		ciclo_hora
	CPI		ciclo_hora, max_ciclosT1		// Verifica si se cumplen los ciclos
	BRNE	FIN_TIMER1
	CLR		ciclo_hora
	SBR		bandera_ACCION, 0b00000001		// Activa el cambio de hora
	SBRC	bandera_ACCION, 4				// Si alarma esta activa
	SBR		bandera_ACCION, 0b00100000		// Activar comparar alarma
FIN_TIMER1:
	POP		R16
	OUT		SREG, R16
	POP		R17
	POP		R16
	RETI

PORTC_ISR:
	PUSH	R16
	PUSH	R17
	IN		R16, SREG
	PUSH	R16

	IN		in_PORTC, PINC	// Lee PIN C
	SBRS	in_PORTC, 0		// PC0 es incremento
	RJMP	INC_DISPLAY
	SBRS	in_PORTC, 1		// PC1 es decremento
	RJMP	DEC_DISPLAY
	SBRS	in_PORTC, 2		// PC2 es aumento de estado
	RJMP	INC_ESTADO
	SBRS	in_PORTC, 3		// PC3 es decremento de estado
	RJMP	DEC_ESTADO
	RJMP	FIN_PORTC_ISR	// Salta al final
	INC_ESTADO:
		LSL		estado			// corre a la izquierda los bits
		CPI		estado, 0x00	// si hay overflow, carga 0x01
		BRNE	FIN_PORTC_ISR
		LDI		estado, 0b00000001
		RJMP	FIN_PORTC_ISR
	DEC_ESTADO:
		LSR		estado			// corre a la derecha los bits
		CPI		estado, 0x00	// Si hay underflow, cargar 0x80
		BRNE	FIN_PORTC_ISR
		LDI		estado, 0b10000000
		RJMP	FIN_PORTC_ISR
	INC_DISPLAY:	// Activa bandera de incremento y verifica la alarma
		SBR		bandera_ACCION, 0b00000100
		RJMP	ALARMA_ON
	DEC_DISPLAY:	// Activa bandera de decremento y verifica la alarma
		SBR		bandera_ACCION, 0b00001000
		RJMP	ALARMA_ON
	ALARMA_ON:		// Se asegura de que este en configuracion alarma
		CPI		estado, 0b01000000
		BREQ	ACT_ALARMA
		CPI		estado, 0b10000000
		BREQ	ACT_ALARMA
		RJMP	FIN_PORTC_ISR
		ACT_ALARMA:
		SBR		bandera_ACCION, 0b00010000 // Bandera de alarma activada
FIN_PORTC_ISR:
	POP		R16
	OUT		SREG, R16
	POP		R17
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