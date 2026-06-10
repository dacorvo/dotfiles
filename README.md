# dotfiles
These are my dotfiles, managed with chezmoi.

## Quick setup

1. Install directly from GitHub.

~~~
curl -fsLS https://raw.githubusercontent.com/dacorvo/dotfiles/master/install.sh | bash
~~~

This installs zsh if needed, installs chezmoi if needed, and applies the managed
source tree directly from the repo.

## Reapply changes

Use chezmoi directly after the initial install.

~~~
chezmoi update
~~~
