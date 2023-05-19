import os
import logging

from slack_bolt.adapter.flask import SlackRequestHandler

from .function.pritunl_slack_app.pritunl_slack import app

LOG_LEVEL = logging.DEBUG if os.getenv("FLASK_DEBUG", 'False').lower() in ('true', '1') else logging.INFO

logging.basicConfig(level=LOG_LEVEL)
from flask import Flask, request
from flask_healthz import healthz

handler = SlackRequestHandler(app)

flask_app = Flask(__name__)
flask_app.config['HEALTHZ'] = {
    "live": "pritunl_slack_app.flask_checks.liveness",
    "ready": "pritunl_slack_app.flask_checks.readiness",
}
flask_app.register_blueprint(healthz, url_prefix="/healthz")

@flask_app.route("/", methods=["POST"])
def slack_events():
    return handler.handle(request)
