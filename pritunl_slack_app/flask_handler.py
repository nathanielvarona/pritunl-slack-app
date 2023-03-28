import logging
from slack_bolt.adapter.flask import SlackRequestHandler

from .function.pritunl_slack import app

logging.basicConfig(level=logging.DEBUG)
from flask import Flask, request

flask_app = Flask(__name__)
handler = SlackRequestHandler(app)

@flask_app.route("/", methods=["POST"])
def slack_events():
    return handler.handle(request)
