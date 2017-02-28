#!/bin/bash
cp -r bin ~
cat .bashrc >> ~/.bashrc
cp .dircolors ~
cp .git* ~
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
cp .vimrc ~
vim +PluginInstall +qall
