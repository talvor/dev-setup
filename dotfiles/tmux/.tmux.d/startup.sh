#!/bin/bash
session="workspace"

if [[ -z "$TMUX" ]] && [[ -t 0 ]] && [[ $- = *i* ]]; then
  # exec tmux attach-session -t $session || exec tmux new-session -s $session
  # Check if the session exists, discarding output
  # We can check $? for the exit status (zero for success, non-zero for failure)
  tmux has-session -t $session 2>/dev/null

  if [ $? != 0 ]; then
    exec tmux new-session -s $session
  fi

  exec tmux attach-session -t $session
fi
