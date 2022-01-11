supported_shells=("zsh bash")

if test -n "$ZSH_VERSION"; then
  SHELL_NAME=zsh
elif test -n "$BASH_VERSION"; then
  SHELL_NAME=bash
fi

export ENVINJ_SHELL=$SHELL_NAME

if [[ ! " ${supported_shells[*]} " =~ " ${ENVINJ_SHELL} " ]]; then
	echo "EJ: Can run only in bash or zsh environment"
	return
fi

command_preexec="$(command -v preexec 2>/dev/null)"

if [ "$command_preexec" != "" ] && [ "$ENVINJ_SHELL" = "zsh" ]; then
	echo "EJ: Can't run in zsh environment that already leverage preexec command."
	return
fi


validate_command () {
	if [ "$1" = "" ]; then
		return
	fi

	for basename in $(basename $1); do
		for skipname in "$ENVINJ_SKIP"; do
			if [ "$basename" = "$skipname" ]; then
				envinj_skipping="yes"
			fi
		done

		if [ "$envinj_skipping" = "yes" ]; then
			continue
		fi

		for appname in "$ENVINJ_APPS"; do
			if [ "$basename" = "$appname" ]; then
				envinj_found="yes"
				envinj_app="$basename"
				break
			fi
		done

		if [ "$envinj_found" = "yes" ]; then
			break
		fi
	done

	echo $envinj_app
}

preexec () {
	if [ "$ENVINJ_PROVIDER" = "" ] && [ "$ENVINJ_APPS" = "" ]; then
		return
	fi

	if [ "$ENVINJ_SHELL" = "bash" ]; then
		command=$BASH_COMMAND
	else
		command=$1
	fi

	echo $command

	ENVINJ_APP=$(validate_command $command)

	if [ "$ENVINJ_APP" != "" ]; then
		echo "EJ: Injecting environment variables for $ENVINJ_APP"
		eval "$ENVINJ_PROVIDER $ENVINJ_APP"
		echo "EJ: Vars set"
	fi
}

if [ "$ENVINJ_SHELL" = "bash" ]; then
	trap 'preexec' DEBUG
fi