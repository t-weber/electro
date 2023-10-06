;
; machine definitions
; @author Tobias Weber
; @date 16-sep-2023
; @license see 'LICENSE' file
;

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
LCD_IO_PINS    = %00111111
LCD_IO_PORT    = IO_PORT1
LCD_IO_PORT_WR = IO_PORT1_WR

LCD_PIN_ENABLE = %00100000
LCD_PIN_RS     = %00010000
; -----------------------------------------------------------------------------
