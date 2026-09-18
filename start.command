#!/bin/zsh

PROJECT="/Users/gauravkumar/ai-customer-support"
XCODE="/Users/gauravkumar/Desktop/AI Customer Support/AI Customer Support.xcodeproj"

echo "======================================"
echo "      🤖 AI CUSTOMER SUPPORT"
echo "======================================"

echo "🔹 Checking Python..."
source "$PROJECT/venv/bin/activate"
echo "✅ Python ready."

echo "🔹 Checking Ollama..."
if pgrep -x "ollama" >/dev/null; then
    echo "✅ Ollama already running."
else
    echo "🔄 Starting Ollama..."
    open -a Ollama
    sleep 5
fi

echo "🔹 Checking FastAPI..."

if lsof -ti :8000 >/dev/null 2>&1; then
    echo "✅ FastAPI already running."
else
    echo "🔄 Starting FastAPI..."

    cd "$PROJECT/backend"

    nohup "$PROJECT/venv/bin/python" -m uvicorn main:app \
    --host 127.0.0.1 \
    --port 8000 \
    > "$PROJECT/logs/fastapi.log" 2>&1 &

    sleep 8

    if lsof -ti :8000 >/dev/null 2>&1; then
        echo "✅ FastAPI started."
    else
        echo "❌ FastAPI failed."
        echo "Check: $PROJECT/logs/fastapi.log"
        exit 1
    fi
fi

echo "🔹 Opening Xcode..."
open "$XCODE"

echo ""
echo "======================================"
echo "             🚀 READY"
echo "======================================"
echo "🤖 Ollama  : RUNNING"
echo "⚡ FastAPI : RUNNING"
echo "📱 Xcode   : OPEN"
echo "🌐 Backend : http://127.0.0.1:8000"
echo ""
echo "Now press ▶ Run in Xcode."
echo "======================================"

read -r "?Press Enter to close..."
