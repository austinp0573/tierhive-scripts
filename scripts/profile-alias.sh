echo -n "" > /etc/motd

cat << 'EOF' > ~/.profile
# /root/.profile

# Set the search path
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Set the editor
export EDITOR=vi
export PAGER=less

# Alpine/Ash compatible prompt structure
export USER=$(whoami)
export PS1='$USER@${HOSTNAME%%.*}:${PWD}# '

# Load aliases if they exist
[ -f ~/.ashrc ] && . ~/.ashrc

# Login info executions
echo "welcome to $HOSTNAME"
echo ""
date
echo ""
EOF

cat << 'EOF' > ~/.ashrc
# Colorize output and make formatting human-readable
alias ls='ls --color=auto'
alias l='ls --color=auto -Alrth'
alias df='df -h'
alias free='free -h'
alias top='top -d 1'

# Safety prompts to prevent accidental overwrites
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
EOF

source .ashrc
