supported_shells=("zsh bash")
bold=$(tput bold)
normal=$(tput sgr0)

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

echoerr() { 
	true
	# echo "$@" 1>&2;
}

validate_command () {
	if [ "$1" = "" ]; then
		return
	fi

	for block in $@; do
		
		if [ "$block" = "" ]; then
			continue
		fi

		echoerr block $block
		fetchedname=$(basename $block 2>/dev/null)  
		envinj_skipping="no"
		for skipname in `echo $ENVINJ_SKIP`; do
			echoerr skip $skipname
			if [ "$fetchedname" = "$skipname" ]; then
				echoerr SKIPPING $block
				envinj_skip="yes"
				break
			fi
		done

		if [ "$envinj_skip" = "yes" ]; then
			break
		fi
		
		IFS=$' \t\n'
		for appname in `echo $ENVINJ_APPS`; do
			echoerr app $appname
			if [ "$fetchedname" = "$appname" ]; then
				envinj_found="yes"
				envinj_app="$appname"
				break
			fi
		done

		if [ "$envinj_found" = "yes" ]; then
			echoerr found $envinj_app
			break
		fi
	done
	
	echo $envinj_app
}

export_env_vars() {
	for envar in $(env | grep '^[0-9a-zA-Z_]\+\=' | cut -d '=' -f 1); do
	if [ "$ENVINJ_SHELL" = "bash" ]; then
		echo "export $envar="\'"${!envar}"\'
	else
		echo "export $envar="\'"${(P)envar}"\'
	fi
		
	done
}

preexec () {
	if [ "$ENVINJ_PROVIDER" = "" ] || [ "$ENVINJ_APPS" = "" ]; then
		echoerr no setup
		return
	fi

	if [ "$ENVINJ_SHELL" = "bash" ]; then
		envinj_command=$BASH_COMMAND
	else
		envinj_command=$1
	fi

	ENVINJ_APP=$(eval "validate_command $envinj_command")

	if [ "$ENVINJ_APP" != "" ]; then
		echo "🔓ej: ${bold}$ENVINJ_APP${normal} needs an injection, passing to ${bold}$ENVINJ_PROVIDER${normal}"
		
		tmpfile=$(mktemp)
		eval "$ENVINJ_PROVIDER $ENVINJ_APP >> $tmpfile"
		new_envs=$(cat $tmpfile)
		rm $tmpfile

		export ENVINJ_STATE="$(export_env_vars | base64)"

		set -o allexport
		source $tmpfile
		set +o allexport

		rm $tmpfile
	fi
}

if [ "$ENVINJ_SHELL" = "bash" ]; then
	trap 'preexec' DEBUG
fi

precmd() {
	if [ "$ENVINJ_STATE" != "" ]; then
		echo "🔓ej: hiding your secrets now and reverting environment"
		
		prev_envs="$(echo $ENVINJ_STATE | tr -d '\n' | tr -d ' ' | base64 -d)"
		echoerr $prev_envs
		for envar in $(env | grep '^[0-9a-zA-Z_]\+\=' | cut -d '=' -f 1); do 
			unset $envar
		done

		eval "$prev_envs"
	fi
}

if [ "$ENVINJ_SHELL" = "bash" ]; then
	PROMPT_COMMAND="precmd"
fi