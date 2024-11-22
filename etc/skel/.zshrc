export XDG_SESSION_TYPE=wayland

export ZSH=$HOME/.oh-my-zsh;
ZSH_THEME="agnoster"
plugins=(git zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh

if [ "$(tty)" = "/dev/tty1" ]; then
    exec sway
elif [ "$(tty)" = "/dev/tty2" ]; then
    htop
fi
