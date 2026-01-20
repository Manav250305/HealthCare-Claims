#!/bin/bash

echo "🔍 Real-Time Log Viewer - Healthcare Claims System"
echo "=================================================="
echo ""
echo "This will show live logs from all Lambda functions"
echo "Press Ctrl+C to stop"
echo ""

# Function to tail logs with color coding
tail_logs() {
    FUNCTION_NAME=$1
    COLOR=$2

    aws logs tail "/aws/lambda/${FUNCTION_NAME}" \
        --since 1m \
        --follow \
        --format short \
        --region us-east-1 2>/dev/null | while read line; do
        echo -e "${COLOR}[${FUNCTION_NAME}]${NC} $line"
    done &
}

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "Starting log streams..."
echo ""

# Tail all three Lambda functions in parallel
tail_logs "claim-orchestrator" "${BLUE}" &
PID1=$!

tail_logs "pdf-extractor" "${GREEN}" &
PID2=$!

tail_logs "risk-scorer" "${YELLOW}" &
PID3=$!

# Trap Ctrl+C and cleanup
trap "kill $PID1 $PID2 $PID3 2>/dev/null; exit" INT

# Wait for user to press Ctrl+C
wait
