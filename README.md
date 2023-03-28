# pritunl-slack-app
Pritunl Slack App Slash Commands

## Installation

```bash
git clone https://github.com/nathanielvarona/pritunl-slack-app.git
cd pritunl-slack-app

poetry install
```

## Flask-Based Environment

## Install the Flask Extras

```bash
poetry install --extras=flask
```

### Development

```bash
poetry run flask run
```

### Production and Deployment

```bash
poetry run gunicorn pritunl_slack_app.flask_handler:flask_app -b 0.0.0.0:9000
```
