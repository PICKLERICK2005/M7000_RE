#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
base=${TMPDIR:-/tmp}/m7000-atcmd-stub-test-$$
sock=$base.sock
log=$base.jsonl
pid=

cleanup() {
  [ -z "$pid" ] || kill "$pid" 2>/dev/null || true
  rm -f "$sock" "$log"
}
trap cleanup EXIT INT TERM

python3 "$repo/emulation/stubs/atcmd-query-stub.py" \
  --socket "$sock" --log "$log" &
pid=$!

i=0
while [ ! -S "$sock" ]; do
  i=$((i + 1))
  [ "$i" -lt 50 ] || { echo "AT stub did not create socket" >&2; exit 1; }
  sleep 0.1
done

python3 "$repo/emulation/scripts/test-atcmd-stub.py" "$sock"

allowed=$(grep -c '"allowed": true' "$log")
rejected=$(grep -c '"allowed": false' "$log")
[ "$allowed" -eq 1 ] && [ "$rejected" -eq 1 ]
if grep -q 'CFUN=0' "$log"; then
  echo "rejected command arguments leaked into log" >&2
  exit 1
fi
echo "AT stub redaction self-test passed"
