# pritunl-slack-app
Pritunl Slack App Slash Commands

## Pritunl Slack Slash Commands Screenshot

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./doc/img/example-pritunl-slack-dark.png">
  <img alt="Pritunl Slack Slash Commands Screenshot" src="./doc/img/example-pritunl-slack-light.png">
</picture>

## Installation

### Flask _(Server)_

#### Install the Flask Extras

```bash
poetry install --extras=flask
```

#### Development

```bash
poetry run flask run
```

#### Production

```bash
poetry run \
 gunicorn pritunl_slack_app.flask_handler:flask_app \
 -b 0.0.0.0:9000
```


### AWS Lambda _(Serverless)_

#### Export Poetry Dependencies to base PIP `requirements.txt`

```bash
poetry export --without-hashes \
  --format requirements.txt \
  --output ./pritunl_slack_app/function/requirements.txt
```

#### SAM Build
```bash
sam build --use-container
```

#### SAM Deployment

```bash
sam deploy --guided
```

> Check out the article [Build a Pritunl Slack Slash Commands with a Serverless Backend](https://nathanielvarona.github.io/posts/build-a-pritunl-slack-slash-commands-with-a-serverless-backend/) for the complete Serverless Backend deployment.
