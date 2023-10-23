;
; machine definitions
; @author Tobias Weber
; @date 16-sep-2023
; @license see 'LICENSE' file
;

.ifndef __MACHINE_DEFS__
__MACHINE_DEFS__ = 1


; -----------------------------------------------------------------------------
; defines
; -----------------------------------------------------------------------------
; timer-based or busy waiting
USE_TIMER_BASED_WAITING = 1
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; memory layout
;
;   ------------  <- 0x0000
;  |            |
;  |    RAM     |  a15 = 0
;  |            |  32 kB
;  |            |
;   ------------  <- 0x8000
;  |   Module   |  a15 = 1, a14 = 0
;  |  ROM / RAM |  16 kB
;   ------------  <- 0xc000
;  |    I/O     |  a15 = 1, a14 = 1, a13 = 0, 8 kB
;   ------------  <- 0xe000
;  |    ROM     |  a15 = 1, a14 = 1, a13 = 1, 8 kB
;   ------------
; -----------------------------------------------------------------------------
ZERO_PAGE     = $0000
STACK_PAGE    = $0100
MOD_START     = $8000
IO_START      = $c000
ROM_START     = $e000

; pseudo-registers in zero-page
REG_SRC_LO    = $00
REG_SRC_HI    = $01
REG_DST_LO    = $02
REG_DST_HI    = $03
REG_IDX_1     = $04
REG_IDX_2     = $05
REG_IDX_3     = $06
REG_IDX_4     = $07
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; I/O, see: https://en.wikipedia.org/wiki/WDC_65C22
; -----------------------------------------------------------------------------
IO_PORT1                 = IO_START + $01
IO_PORT2                 = IO_START + $00
IO_PORT1_WR              = IO_START + $03
IO_PORT2_WR              = IO_START + $02

IO_TIMER1_CTR_LOW        = IO_START + $04
IO_TIMER1_CTR_HIGH       = IO_START + $05
IO_TIMER1_LATCH_LOW      = IO_START + $06
IO_TIMER1_LATCH_HIGH     = IO_START + $07
IO_TIMER2_CTR_LOW        = IO_START + $08
IO_TIMER2_CTR_HIGH       = IO_START + $09

IO_SHIFT                 = IO_START + $0a

IO_AUX_CTRL              = IO_START + $0b
IO_AUX_TIMER1_CONT       = %01000000

IO_INT_FLAGS             = IO_START + $0d
IO_INT_ENABLE            = IO_START + $0e
IO_INT_FLAG_IRQSET       = %10000000
IO_INT_FLAG_TIMER1       = %01000000
IO_INT_FLAG_TIMER2       = %00100000
IO_INT_FLAG_CB1          = %00010000
IO_INT_FLAG_CB2          = %00001000
IO_INT_FLAG_SHIFT        = %00000100
IO_INT_FLAG_CA1          = %00000010
IO_INT_FLAG_CA2          = %00000001

IO_PORTS_CTRL            = IO_START + $0c
IO_PORTS_CB2_POSEDGE     = %01000000
IO_PORTS_CB2_POSEDGE_IND = %01100000
IO_PORTS_CB2_NEGEDGE_IND = %00100000
IO_PORTS_CB1_POSEDGE     = %00010000
IO_PORTS_CA2_POSEDGE     = %00000100
IO_PORTS_CA2_POSEDGE_IND = %00000110
IO_PORTS_CA2_NEGEDGE_IND = %00000010
IO_PORTS_CA1_POSEDGE     = %00000001
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; LCD, see: https://www.arduino.cc/documents/datasheets/LCDscreen.PDF
; -----------------------------------------------------------------------------
; output to port 1 pins: enable, register select, data 7-4
LCD_IO_PINS_WR      = %00111111
LCD_IO_PORT         = IO_PORT1
LCD_IO_PORT_WR      = IO_PORT1_WR

LCD_PIN_ENABLE      = %00100000
LCD_PIN_RS          = %00010000

LCD_CARET_DIR_INC   = %00000010
LCD_CARET_DIR_SHIFT = %00000001

LCD_DISP_ON         = %00000100
LCD_DISP_CARET_LINE = %00000010
LCD_DISP_CARET_BOX  = %00000001

LCD_SHIFT_ALL       = %00001000
LCD_SHIFT_RIGHT     = %00000100

LCD_FUNC_8BITS      = %00000001  ; in upper nibble
LCD_FUNC_2LINES     = %00001000
LCD_FUNC_FONT       = %00000100

.ifdef USE_TIMER_BASED_WAITING
LCD_SLEEP_BASE      = 5          ; has to be >= 1 ms
.else
LCD_SLEEP_BASE      = 1          ; has to be >= 1 ms
.endif

LCD_LINE_LEN        = 40         ; characters per line (even if not all are visible)
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; status leds
; -----------------------------------------------------------------------------
LED_PIN_RED         = %10000000
LED_PIN_GREEN       = %01000000

LED_IO_PINS_WR      = LED_PIN_RED | LED_PIN_GREEN
LED_IO_PORT         = IO_PORT1
LED_IO_PORT_WR      = IO_PORT1_WR
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; passive piezo buzzer
; -----------------------------------------------------------------------------
PIEZO_PIN           = %01000000

PIEZO_IO_PINS_WR    = PIEZO_PIN
PIEZO_IO_PORT       = IO_PORT2
PIEZO_IO_PORT_WR    = IO_PORT2_WR
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; keys parallel and keypad serial interface,
; see: https://www.engineersgarage.com/arduino-ttp229-touch-keypad-interfacing/
; -----------------------------------------------------------------------------
KEYPAD_IO_PIN_CLK   = %00010000
KEYPAD_IO_PIN_DAT   = %00100000
KEYPAD_IO_PINS_WR   = KEYPAD_IO_PIN_CLK
KEYPAD_IO_MASK      = KEYPAD_IO_PIN_CLK | KEYPAD_IO_PIN_DAT
KEYPAD_IO_PORT      = IO_PORT2
KEYPAD_IO_PORT_WR   = IO_PORT2_WR

.ifdef USE_TIMER_BASED_WAITING
KEYPAD_INIT_DELAY   = 10                 ; has to be >= 10 mus
KEYPAD_PULSE_DELAY  = 5                  ; has to be >= 1 ms
.else
KEYPAD_INIT_DELAY   = 1                  ; has to be >= 10 mus
KEYPAD_PULSE_DELAY  = 1                  ; has to be >= 1 ms
.endif

KEYS_IO_PINS_WR     = KEYPAD_IO_PINS_WR  ; on the same pin header
KEYS_IO_MASK        = %00001111
KEYS_IO_PORT        = IO_PORT2
KEYS_IO_PORT_WR     = IO_PORT2_WR

KEYS_PIN_1          = %00000001
KEYS_PIN_2          = %00000010
KEYS_PIN_3          = %00000100
KEYS_PIN_4          = %00001000
; -----------------------------------------------------------------------------


.endif
