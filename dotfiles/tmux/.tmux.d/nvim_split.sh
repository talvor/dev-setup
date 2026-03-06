#!/bin/bash

# Check if the shell is in a tmux session
if [ -z "$TMUX" ]; then
    echo "Not in a tmux session. Please run this script within a tmux session."
    exit 1
fi

# Split the terminal horizontally (left and right panes)
tmux split-window -h

# Launch nvim in the left pane
tmux send-keys -t "{left}" "nvim ." Enter
