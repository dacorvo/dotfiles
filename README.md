# dofiles
These are just my dotfiles ...

##Quick setup

1. Install utility scripts

~~~
cp -r bin ~
~~~

2. Update .bashrc

~~~
cat .bashrc >> ~/.bashrc
~~~

3. Setup Git

~~~
sudo apt-get install git
cp .git* ~
~~~

3. Setup Vim

~~~
sudo apt-get install vim
git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
cp .vimrc ~
vim +PluginInstall +qall
~~~

4. Setup YouCompleteMe

~~~
sudo apt-get install build-essential cmake
sudo apt-get install python-dev
cd ~/.vim/bundle/YouCompleteMe
./install.sh --clang-completer
~~~
