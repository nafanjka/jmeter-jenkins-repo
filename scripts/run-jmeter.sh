#!/usr/bin/env bash
set -euo pipefail

# JMeter runner using local JMeter on PATH.
# Reads JMX from JMX_PATH, writes results to results/<test>_<timestamp>.

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT"

# Params (env or defaults)
JMX_PATH="${JMX_PATH:-tests/example.jmx}"
RESULTS_ROOT="${RESULTS_ROOT:-$ROOT/results}"
TS="$(date +%Y%m%d-%H%M%S)"
BASE_NAME="$(basename "$JMX_PATH")"
TEST_NAME="${BASE_NAME%.*}"
RESULTS_DIR="${RESULTS_DIR:-$RESULTS_ROOT/${TEST_NAME}_${TS}}"
ENDPOINT="${ENDPOINT:-}"

# Common JMeter tuning params
THREADS="${THREADS:-}"            # -Jthreads
DURATION="${DURATION:-}"          # -Jduration
RAMP_UP="${RAMP_UP:-}"            # -Jrampup
LOOP_COUNT="${LOOP_COUNT:-}"      # -Jloopcount

mkdir -p "$RESULTS_DIR"

# Build -J flags from env
J_FLAGS=()
add_j_flag() { local k="$1"; local v="$2"; [[ -n "$v" ]] && J_FLAGS+=("-J${k}=${v}"); }
add_j_flag "threads" "$THREADS"
add_j_flag "duration" "$DURATION"
add_j_flag "rampup" "$RAMP_UP"
add_j_flag "loopcount" "$LOOP_COUNT"

# Parse ENDPOINT into protocol, host, port and add -J flags
if [[ -n "$ENDPOINT" ]]; then
  ep="$ENDPOINT"
  protocol=""
  host=""
  port=""
  if [[ "$ep" =~ ^([a-zA-Z][a-zA-Z0-9+.-]*):// ]]; then
    protocol="${BASH_REMATCH[1]}"
    rest="${ep#*://}"
  else
    protocol="http"
    rest="$ep"
  fi
  hostport="${rest%%/*}"
  if [[ "$hostport" == *:* ]]; then
    host="${hostport%%:*}"
    port="${hostport#*:}"
  else
    host="$hostport"
    if [[ "$protocol" == "https" ]]; then
      port="443"
    else
      port="80"
    fi
  fi
  add_j_flag "protocol" "$protocol"
  add_j_flag "host" "$host"
  add_j_flag "port" "$port"
fi

# Compose jmeter command
JMETER_CMD=( jmeter -n -t "$JMX_PATH" -l "$RESULTS_DIR/results.jtl" -j "$RESULTS_DIR/jmeter.log" )
JMETER_CMD+=( "${J_FLAGS[@]}" )

# Control HTML report generation via env var (default: true)
HTML_REPORT="${HTML_REPORT:-true}"
if [[ "$HTML_REPORT" == "true" || "$HTML_REPORT" == "1" ]]; then
  JMETER_CMD+=( -e -o "$RESULTS_DIR/report" )
fi

# Validate JMX exists
if [[ ! -f "$JMX_PATH" ]]; then
  echo "JMX file not found: $JMX_PATH" >&2
  exit 2
fi

echo "> Running local JMeter (jmeter must be available on PATH)"
command -v jmeter >/dev/null || { echo "jmeter not found on PATH" >&2; exit 3; }
"${JMETER_CMD[@]}"

echo "\n=== Artifacts ==="
echo "Results JTL : $RESULTS_DIR/results.jtl"
echo "JMeter log  : $RESULTS_DIR/jmeter.log"
if [[ -d "$RESULTS_DIR/report" ]]; then
  echo "HTML report : $RESULTS_DIR/report/index.html"
fi
