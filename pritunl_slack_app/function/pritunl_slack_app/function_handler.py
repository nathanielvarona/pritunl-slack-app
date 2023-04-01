import logging
from slack_bolt.adapter.aws_lambda import SlackRequestHandler

SlackRequestHandler.clear_all_log_handlers()
logging.basicConfig(format="%(asctime)s %(message)s", level=logging.INFO)

def handler(event, context):

    from .pritunl_slack import app

    slack_handler = SlackRequestHandler(app=app)
    return slack_handler.handle(event, context)
