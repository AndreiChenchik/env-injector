# env-injector

1. clone
2. add to .zshrc or .bashrc `source /home/vscode/env-injector/activate.sh`
3. add selector for app `export ENVINJ_APPS="uvicorn kubectl"`
4. add secrets provider `export ENVINJ_PROVIDER='1penv $1'` to `$1` will be passed an app name defined in the selector 


Works great with https://direnv.net to define per-project rules
