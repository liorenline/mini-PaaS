# mini-PaaS

A minimal Heroku-style platform built from scratch with Bash, Git and systemd.
Push code with `git push` and the platform deploys it automatically.

This is a learning project that grows step by step.

## How it works

```
git push paas main
        │
        ▼
bare repo on the server  (~/<app>.git)
        │  post-receive hook
        ▼
checkout code to /tmp/<app>
        │
        ▼
deploy.sh → /var/www/<app> → npm install → systemd service
        │
        ▼
app is running on its own port
```

1. Each app has its own bare Git repository on the server.
2. After a push, the `post-receive` hook checks out the code into a temporary folder.
3. The hook calls `deploy.sh`, which copies the code, installs dependencies and (re)starts the app as a systemd service.
4. systemd keeps the app running, restarts it on failure and starts it after a reboot.

The app name is taken from the repository name, and the port is stored in the repository's Git config (`paas.port`), so the same hook works for every app.

## Project structure

```
.
├── Vagrantfile               # local Ubuntu VM
├── platform/
│   ├── setup.sh              # one-time server setup (installs Node.js)
│   ├── create-app.sh         # creates a new app: bare repo + hook + port
│   ├── post-receive          # Git hook template, copied into every app repo
│   └── deploy.sh             # deploys an app as a systemd service
└── app/test/                 # example Node.js app
```

## Requirements

- macOS on Apple Silicon
- [UTM](https://mac.getutm.app/)
- [Vagrant](https://www.vagrantup.com/) with the `vagrant_utm` plugin

## Quick start

### 1. Start the server

```bash
vagrant plugin install vagrant_utm
vagrant up
```

`setup.sh` runs automatically on the first `vagrant up`.

### 2. Configure SSH access

Run `vagrant ssh-config`, copy the output to `~/.ssh/config` and rename `Host default` to `Host paas`. Check it with:

```bash
ssh paas
```

### 3. Create an app

On the server:

```bash
/vagrant/platform/create-app.sh hello 3001
```

### 4. Deploy

In your app's folder on your machine:

```bash
git remote add paas paas:hello.git
git push paas main
```

The deploy output appears right in your terminal. Check the app on the server:

```bash
curl localhost:3001
```

## App requirements

For now the platform supports Node.js apps only. An app must:

- have a `package.json` with a `start` script;
- listen on the port from the `PORT` environment variable.

## Current limitations

- Runs only in a local Vagrant VM on macOS (UTM provider).
- Node.js apps only.
- Apps are reachable by port, not by domain name.
- No HTTPS, logs or metrics yet.
