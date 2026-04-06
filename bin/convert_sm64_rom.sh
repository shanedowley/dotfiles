#!/bin/bash

set -euo pipefail

INPUT="${1:-supermario64.n64}"
OUTPUT="baserom.us.z64"

if [[ ! -f "$INPUT" ]]; then
  echo "Error: input file not found: $INPUT"
  echo "Usage: $0 [input_file]"
  exit 1
fi

python3 - "$INPUT" "$OUTPUT" <<'PY'
import sys
from pathlib import Path

src = Path(sys.argv[1])
dst = Path(sys.argv[2])

data = bytearray(src.read_bytes())

# Convert .n64 byte-swapped format to .z64 big-endian format
# Swap each 16-bit pair: AB CD -> BA DC
for i in range(0, len(data), 2):
    if i + 1 < len(data):
        data[i], data[i + 1] = data[i + 1], data[i]

dst.write_bytes(data)
print(f"Converted {src} -> {dst}")
PY

echo
echo "Done."
echo "Output file: $OUTPUT"
echo
echo "Check hash with:"
echo "  shasum $OUTPUT"
