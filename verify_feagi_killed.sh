#!/bin/bash
# Verify that all FEAGI processes are killed after shutdown

echo "🔍 Checking for running FEAGI processes..."
echo ""

# Check for FEAGI binary processes
FEAGI_PROCS=$(pgrep -fl feagi | grep -v "verify_feagi_killed" || true)

if [ -z "$FEAGI_PROCS" ]; then
    echo "✅ No FEAGI processes found (clean shutdown)"
    echo ""
else
    echo "❌ FEAGI processes still running:"
    echo "$FEAGI_PROCS"
    echo ""
    echo "To kill them manually:"
    pgrep -f feagi | grep -v "verify_feagi_killed" | while read pid; do
        echo "  kill -9 $pid"
    done
    echo ""
fi

# Check if ports are still in use
echo "🔍 Checking FEAGI ports..."
echo ""

# Check HTTP port 8000
HTTP_PORT=$(lsof -i :8000 -sTCP:LISTEN -t 2>/dev/null || true)
if [ -z "$HTTP_PORT" ]; then
    echo "✅ Port 8000 (HTTP API) is free"
else
    echo "❌ Port 8000 (HTTP API) still in use by PID: $HTTP_PORT"
    echo "   Process: $(ps -p $HTTP_PORT -o comm= || echo 'unknown')"
fi

# Check WebSocket port 9050
WS_PORT=$(lsof -i :9050 -sTCP:LISTEN -t 2>/dev/null || true)
if [ -z "$WS_PORT" ]; then
    echo "✅ Port 9050 (WebSocket) is free"
else
    echo "❌ Port 9050 (WebSocket) still in use by PID: $WS_PORT"
    echo "   Process: $(ps -p $WS_PORT -o comm= || echo 'unknown')"
fi

echo ""
echo "🔍 Checking FEAGI state directory..."
STATE_DIR="$HOME/Library/Application Support/BrainVisualizer/feagi"
if [ -d "$STATE_DIR" ]; then
    echo "❌ State directory still exists: $STATE_DIR"
    echo "   Contents:"
    ls -la "$STATE_DIR" 2>/dev/null | sed 's/^/   /'
else
    echo "✅ State directory cleaned up"
fi

echo ""
echo "🔍 Checking FEAGI launch logs..."
LOG_FILE="$HOME/Library/Logs/BrainVisualizer/feagi_launch.log"
if [ -f "$LOG_FILE" ]; then
    echo "❌ Launch log still exists: $LOG_FILE"
    echo "   Last 10 lines:"
    tail -10 "$LOG_FILE" 2>/dev/null | sed 's/^/   /'
else
    echo "✅ Launch log cleaned up"
fi

echo ""
echo "═══════════════════════════════════════════════════"
if [ -z "$FEAGI_PROCS" ] && [ -z "$HTTP_PORT" ] && [ -z "$WS_PORT" ] && [ ! -d "$STATE_DIR" ] && [ ! -f "$LOG_FILE" ]; then
    echo "✅ COMPLETE SHUTDOWN VERIFIED"
    echo "   All FEAGI processes killed, ports freed, state cleaned"
else
    echo "⚠️  INCOMPLETE SHUTDOWN DETECTED"
    echo "   Some FEAGI resources are still active"
fi
echo "═══════════════════════════════════════════════════"

