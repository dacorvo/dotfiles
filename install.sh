#!/usr/bin/env bash
set -euo pipefail

install_zsh() {
	if command -v zsh >/dev/null 2>&1; then
		return
	fi

	case "$(uname -s)" in
		Darwin)
			if command -v brew >/dev/null 2>&1; then
				brew install zsh
				return
			fi
			;;
		Linux)
			if command -v apt-get >/dev/null 2>&1; then
				sudo apt-get update
				sudo apt-get install -y zsh
				return
			fi
			if command -v dnf >/dev/null 2>&1; then
				sudo dnf install -y zsh
				return
			fi
			if command -v pacman >/dev/null 2>&1; then
				sudo pacman -S --noconfirm zsh
				return
			fi
			;;
	esac

	echo "zsh is not installed and no supported package manager was found." >&2
	echo "Install zsh manually, then rerun the bootstrap." >&2
	exit 1
}

install_chezmoi() {
	if command -v chezmoi >/dev/null 2>&1; then
		return
	fi

	if command -v brew >/dev/null 2>&1; then
		brew install chezmoi
		return
	fi

	mkdir -p "$HOME/.local/bin"
	sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
	export PATH="$HOME/.local/bin:$PATH"
}

repo_url="https://github.com/dacorvo/dotfiles.git"

install_zsh
install_chezmoi
chezmoi init --apply "$repo_url"
