#!/bin/bash

echo "📊 Detailed Execution Logs - Last Run"
echo "======================================"
echo ""

REGION="us-east-1"

# Function to get recent logs with proper formatting
get_recent_logs() {
    FUNCTION=$1
    TITLE=$2
    COLOR=$3

    echo -e "${COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${COLOR}${TITLE}${NC}"
    echo -e "${COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    aws logs tail "/aws/lambda/${FUNCTION}" \
        --since 5m \
        --format detailed \
        --region "${REGION}" 2>/dev/null

    echo ""
}

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Fetching logs from last 5 minutes..."
echo ""

# Show logs in execution order
get_recent_logs "claim-orchestrator" "1️⃣  ORCHESTRATOR - Workflow Manager" "${BLUE}"
get_recent_logs "pdf-extractor" "2️⃣  PDF EXTRACTOR - Text Extraction" "${GREEN}"
get_recent_logs "risk-scorer" "3️⃣  RISK SCORER - Analysis Engine" "${YELLOW}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Log fetch complete!"
echo ""
echo "To see live logs as they happen, run:"
echo "  ./watch-logs.sh"
