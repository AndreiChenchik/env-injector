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

# if [ "$command_preexec" != "" ] && [ "$ENVINJ_SHELL" = "zsh" ]; then
# 	echo "EJ: Can't run in zsh environment that already leverage preexec command."
# 	return
# fi

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
		fetchedname=$(basename $block)  
		envinj_skipping="no"
		for skipname in `echo $ENVINJ_SKIP`; do
			echoerr skip $skipname
			if [ "$fetchedname" = "$skipname" ]; then
				envinj_skipping="yes"
			fi
		done
		if [ "$envinj_skipping" = "yes" ]; then
			echoerr SKIPPING $block
			continue
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
	while read -r env_line
	do
		IFS='=' read -r key value <<< "$env_line"
  	echo "export $key="$'\''"$value"$'\''
	done <<< "$(env)"
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
		echo "EJ: Injecting environment variables for $ENVINJ_APP"
		
		ej_user_command="user_command () { $ENVINJ_PROVIDER; }"
		echoerr $ej_user_command
		eval "$ej_user_command"
		new_envs=$(user_command $ENVINJ_APP)

		export ENVINJ_STATE="$(export_env_vars | base64)"

		eval "$(echo $new_envs | awk '$0="export "$0')"

		echo "EJ: Vars set"
	fi
}

if [ "$ENVINJ_SHELL" = "bash" ]; then
	trap 'preexec' DEBUG
fi

precmd() {
	if [ "$ENVINJ_STATE" != "" ]; then
		echo "EJ: Reverting environment to previosly set variables"
		
		
		prev_envs="$(echo $ENVINJ_STATE | tr -d '\n' | tr -d ' ' | base64 -d)"
		echoerr $prev_envs
		for envar in $(env | cut -d '=' -f 1); do unset $envar; done
		eval "$prev_envs"
	fi
}

if [ "$ENVINJ_SHELL" = "bash" ]; then
	PROMPT_COMMAND="precmd"
fi