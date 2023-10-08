;
; machine definitions
; @author Tobias Weber
; @date 16-sep-2023
; @license see 'LICENSE' file
;

.ifndef __MACHINE_DEFS__
__MACHINE_DEFS__ = 1


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
REG_SRC_LO    = $0000
REG_SRC_HI    = $0001
REG_DST_LO    = $0002
REG_DST_HI    = $0003
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; I/O, see: https://en.wikipedia.org/wiki/WDC_65C22
; -----------------------------------------------------------------------------
IO_PORT1      = $c001
IO_PORT2      = $c000
IO_PORT1_WR   = $c003
IO_PORT2_WR   = $c002

IO_TIMER1_CTR_LOW    = $c004
IO_TIMER1_CTR_HIGH   = $c005
IO_TIMER1_LATCH_LOW  = $c006
IO_TIMER1_LATCH_HIGH = $c007
IO_TIMER2_CTR_LOW    = $c008
IO_TIMER2_CTR_HIGH   = $c009

IO_SHIFT      = $c00a

IO_AUX_CTRL   = $c00b
IO_PORTS_CTRL = $c00c

IO_INT_FLAGS  = $c00d
IO_INT_ENABLE = $c00e
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

LCD_SLEEP_BASE      = 1          ; has to be >= 1 ms

LCD_LINE_LEN        = 40         ; characters per line (even if not all are visible)
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; status leds
; -----------------------------------------------------------------------------
LED_IO_PINS_WR      = %11000000
LED_IO_PORT         = IO_PORT1
LED_IO_PORT_WR      = IO_PORT1_WR

LED_PIN_RED         = %10000000
LED_PIN_GREEN       = %01000000
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; keypad parallel interface
; -----------------------------------------------------------------------------
KEYPAD_IO_PINS_WR   = %00000000
KEYPAD_IO_PORT      = IO_PORT2
KEYPAD_IO_PORT_WR   = IO_PORT2_WR
; -----------------------------------------------------------------------------


.endif
