#!/bin/bash
# Terminal UI Editor を実行

cd /home/shun417jp
source venv/bin/activate
python3 terminal_ui.py "${1:-.}"
