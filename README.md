# dotfiles
These are my dotfiles, managed with chezmoi.

## Quick setup

1. Run the bootstrap script from the repo root.

~~~
./setup.sh
~~~

This installs zsh if needed, installs chezmoi if needed, and applies the managed
source tree under [chezmoi/](chezmoi).

## Reapply changes

Re-run the same command whenever you want to reapply the current repo state.
If chezmoi is already installed, the bootstrap simply reuses it.

~~~
./setup.sh
~~~
