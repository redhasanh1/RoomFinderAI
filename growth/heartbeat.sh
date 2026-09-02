#!/bin/sh
# Appends a traction row every 10 minutes so we have a time series rather
# than a single reading. Pure data collection - it does not wake the agent.
while true; do
  python "C:/Documents In C local/roomfinder/RoomFinderAI/growth/monitor.py" \
    >> "C:/Documents In C local/roomfinder/RoomFinderAI/growth/data/heartbeat.log" 2>&1
  sleep 600
done
