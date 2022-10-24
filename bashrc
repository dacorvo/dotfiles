# Custom configuration to add after .bashrc

# Use 256 colors
if [ -n "$DISPLAY" -a "$TERM" == "xterm" ]; then
    export TERM=xterm-256color
fi

# Set path
PATH=~/bin:$PATH

# Add path to toolchain dirs
if [ -d '~/x-tools' ]; then
for dir in `ls ~/x-tools`; do
PATH=~/x-tools/$dir/bin:$PATH
done
fi

# remove duplicates from the path
export PATH=`awk -F: '{for(i=1;i<=NF;i++){if(!($i in a)){a[$i];printf s$i;s=":"}}}'<<<$PATH`;

# Set history
export HISTSIZE=32768;
export HISTFILESIZE=$HISTSIZE;
# don't log duplicate commands and blank commands
export HISTCONTROL=ignoreboth;
# list of commands that should not be added to history
export HISTIGNORE="exit:[bf]g"

# make `vi` the default system editor
export EDITOR='vi';

# Get vimrc from dotfiles directory
alias vi='vi -u ~/dotfiles/vimrc'

# make `man` use use `less` for paging and not clear the screen upon exit
export MANPAGER='less -X';

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Make sure git talks english
alias git='LANGUAGE=en LANG=en_US.UTF-8 git'

# Add git info to prompt
source ~/bin/bash_gitprompt

# Restore tmux session if any
if test -z "$TMUX"; then
  session_num=$(
    tmux list-sessions |
    grep -v attached |
    grep -oP '^\d+:' |
    grep -oP '^\d+' |
    head -1
  )
  if test $session_num; then
    exec tmux attach -t $session_num
  fi
fi
