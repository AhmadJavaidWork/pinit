# pinit
pinit is a tmux session initializer that reads a config file and then starts and attaches to a sessoin defined in that config file

## Usage
```bash
pinit pinit-session example-conf.json
```

### Args
```bash
pinit <session-name> [config-file]
```
- `<session-name>`: Session name to create
- `[config-file]`: Config file path, default is `~/.config/pinit/conf.json`

## Setup
- Download a release from the [releases page](https://github.com/AhmadJavaidWork/pinit/releases)
- After extracting the release, copy the binary to `/usr/local/bin`
- Create a `conf.json` in `~/.config/pinit` according to the [example-conf.json](https://github.com/AhmadJavaidWork/pinit/blob/main/example-conf.json)
- And then simply run it using `pinit <session-name>`
