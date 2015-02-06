# Custom configuration to add after .bashrc

# Use 256 colors
if [ -n "$DISPLAY" -a "$TERM" == "xterm" ]; then
    export TERM=xterm-256color
fi

# Set directory colors (GNU ls)
eval `dircolors ~/.dir_colors`

# Set path
export PATH=~/bin:$PATH

# remove duplicates from the path
export PATH=`awk -F: '{for(i=1;i<=NF;i++){if(!($i in a)){a[$i];printf s$i;s=":"}}}'<<<$PATH`;

# Set proxy

# Always use tsocks if available
which tsocks &> /dev/null && . tsocks -on

# Set history
export HISTSIZE=32768;
export HISTFILESIZE=$HISTSIZE;
# don't log duplicate commands and blank commands
export HISTCONTROL=ignoreboth;
# list of commands that should not be added to history
export HISTIGNORE="exit:[bf]g"

# make `vi` the default system editor
export EDITOR='vi';

# make `man` use use `less` for paging and not clear the screen upon exit
export MANPAGER='less -X';

# Make sure git talks english
alias git='LANGUAGE=en LANG=en_US.UTF-8 git'

# Add git info to prompt
source ~/bin/bash_gitprompt
