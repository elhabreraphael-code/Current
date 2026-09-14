"""Generate two short, softly enveloped original tones; no external assets."""
import math
from pathlib import Path
import struct
import sys
import wave

destination = Path(sys.argv[1])
for name, reverse in [("Connect", False), ("Disconnect", True)]:
    rate, duration = 44100, 0.48
    samples = []
    for i in range(int(rate * duration)):
        t = i / rate
        total = 0.0
        for offset, frequency in [(0, 523.25), (0.085, 783.99)]:
            if reverse:
                frequency = 783.99 if offset == 0 else 523.25
            u = t - offset
            if u >= 0:
                envelope = (1 - math.exp(-u * 110)) * math.exp(-u * 12)
                total += math.sin(2 * math.pi * frequency * u) * envelope * 0.22
        total *= min(1, (duration - t) / 0.035)
        samples.append(struct.pack("<h", int(max(-1, min(1, total)) * 32767)))
    with wave.open(str(destination / (name + ".wav")), "wb") as output:
        output.setparams((1, 2, rate, 0, "NONE", "not compressed"))
        output.writeframes(b"".join(samples))
