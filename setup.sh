#!/bin/bash
cp -r bin ~
cat .bashrc >> ~/.bashrc
cp .dircolors ~
cp .git* ~
cp .tmux.conf ~
git submodule update --init --recursive
cd vim/pack/plugins/start/YouCompleteMe && python3 install.py --clang-completer
