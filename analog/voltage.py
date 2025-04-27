#
# simple voltage converter calculation
# @author Tobias Weber <tobias.weber@tum.de>
# @date 27-april-2025
# @license see 'LICENSE' file
#
# measured:
#   Vcc = 5.05 V
#   4.85 V (before LED)
#   2.15 V (after LED)
#   Vp = 1.71 V
#


# -----------------------------------------------------------------------------
# voltage divider for Opamp's Vp
# -----------------------------------------------------------------------------
Vcc  = 5.05
Vcc -= 2.9  # voltage drop by LED

Ra = 1000. + 200.
Rb = 2500. + 1500.

Vp = Vcc * Rb / (Ra + Rb)
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# non-inverting amplifier
# see: https://en.wikipedia.org/wiki/Operational_amplifier#Non-inverting_amplifier
# -----------------------------------------------------------------------------
R1 = 10000.
R2 = 10000.

A = 100000.
Vout = Vp / (R1 / (R1 + R2) + 1./A)
# -----------------------------------------------------------------------------


print("Vcc  = %.3f V" % Vcc)
print("Vp   = %.3f V" % Vp)
print("Vout = %.3f V" % Vout)
