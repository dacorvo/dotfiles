# dotfiles
These are just my dotfiles ...

## Quick setup

1. Install utility scripts

~~~
cp -r bin ~
~~~

2. Update .bashrc

~~~
cat .bashrc >> ~/.bashrc
~~~

3. Set dir colors

~~~
cp .dircolors ~
~~~

4. Setup Git

~~~
sudo apt-get install git
cp .git* ~
~~~

5. Setup tmux

~~~
cp .tmux.conf ~
~~~

6. Setup Vim plugins (as submodules)

~~~
git submodule update --init --recursive
~~~

7. Setup YouCompleteMe

~~~
cd vim/pack/dcorvoysier/start/YouCompleteMe && python3 install.py --clang-completer
~~~
