# pinit
pinit is a tmux session initializer that reads a config file and then starts and attaches to a sessoin defined in that config file

## Usage
```bash
pinit -s pinit-session -f example-conf.json
```

### Flags
- `-s`: `session name`
- `-f`: `config file path` default is ~/.config/pinit/conf.json

## Setup
- Download a release
- After extracting copy it to /usr/local/bin
- Create a conf.json in ~/.config/pinit according to the example-conf.json
- And then simply run it using `pinit -s {session-name}`
