# set D environment variables
if [ -d "/usr/local/d/" ] ; then
	export DPATH="/usr/local/d/" # d's root path
fi
if [ -f "/usr/bin/dmd" ] ; then
	export DPATH="/usr" # d's root path
	export DROOT="/usr"
fi

if [[ -n "$DPATH" ]] ; then
	if [ -d "$HOME/Documents/Programming/d" ] ; then
		DPATH="$HOME/Documents/Programming/d:$DPATH" # user's d path
	fi
	if [ -d "/usr/local/d/bin" ] ; then
		PATH="/usr/local/d/bin:$PATH"
	fi
	if [ -d "$HOME/Documents/Programming/d/bin" ] ; then
		PATH="$HOME/Documents/Programming/d/bin:$PATH" # add installed d apps to user's path
	fi
fi
