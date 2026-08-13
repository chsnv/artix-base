#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
export DONTFORGET_SECRET_KEY=REDACTED
# PS1='[\u@\h \W]\$ '

# local, untracked secrets
[ -f ~/.zshrc.local ] && . ~/.zshrc.local
