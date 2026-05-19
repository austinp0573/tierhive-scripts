#!/bin/sh

# setup a new user ~ after creation

set -e

# Define target files
PROFILE_FILE="$HOME/.profile"
ASHRC_FILE="$HOME/.ashrc"

# Generate .profile
cat << 'EOF' > "$PROFILE_FILE"
# Set preferred text editor
export EDITOR='vi'

# Configure a clean, informative command prompt: username@hostname:current_directory$
export PS1='\u@\h:\w\$ '

# Include the user's personal bin directory in the system execution PATH if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
export PATH

# Source .ashrc if it exists and we're in an interactive shell
if [ -f "$HOME/.ashrc" ]; then
    . "$HOME/.ashrc"
fi

# Login info executions
echo ""
echo ""
echo "welcome to $HOSTNAME"
echo ""
date
echo ""
EOF

# Generate .ashrc
cat << 'EOF' > "$ASHRC_FILE"
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

# Set appropriate user permissions
chmod 644 "$PROFILE_FILE" "$ASHRC_FILE"

echo "environment files .profile and .ashrc successfully generated"