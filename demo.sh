#!/bin/bash
# Demo script for Wotin time tracker

echo "=== Wotin Time Tracker Demo ==="
echo ""

echo "1. Starting work on project-alpha with backend and api tags..."
./build/wotin start project-alpha +backend +api
sleep 1

echo ""
echo "2. Checking status..."
./build/wotin status

echo ""
echo "3. Switching to project-beta (auto-stops project-alpha)..."
sleep 1
./build/wotin start project-beta +frontend +ui +urgent

echo ""
echo "4. Stopping current work..."
sleep 1
./build/wotin stop

echo ""
echo "5. Viewing all frame IDs..."
./build/wotin frames | head -5

echo ""
echo "6. Viewing activity log..."
./build/wotin log | head -20

echo ""
echo "7. Viewing time report..."
./build/wotin report

echo ""
echo "8. Exporting log as JSON..."
./build/wotin log --json | head -c 300
echo "..."

echo ""
echo ""
echo "=== Demo Complete ==="
echo "Try these commands yourself:"
echo "  wotin start myproject +tag1 +tag2"
echo "  wotin status"
echo "  wotin stop"
echo "  wotin log"
echo "  wotin report"
