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

set_login_shell_zsh() {
	local zsh_path target_user
	zsh_path="$(command -v zsh)" || return 0
	target_user="$(id -un)"

	# Already logging in with zsh? Nothing to do.
	case "${SHELL:-}" in
		*/zsh) return 0 ;;
	esac

	# chsh only accepts shells listed in /etc/shells.
	if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
		echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null 2>&1 || true
	fi

	if sudo chsh -s "$zsh_path" "$target_user"; then
		echo "Login shell set to $zsh_path (takes effect on next login)."
	else
		echo "Could not change the login shell automatically." >&2
		echo "Run manually:  sudo chsh -s $zsh_path $target_user" >&2
	fi
}

repo_url="https://github.com/dacorvo/dotfiles.git"

install_zsh
install_chezmoi
chezmoi init --apply "$repo_url"
set_login_shell_zsh
