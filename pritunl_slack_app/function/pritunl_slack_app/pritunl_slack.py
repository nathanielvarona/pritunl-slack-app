import os
import string
import json

from random import choice

from slack_bolt import App

from pritunl_api import Pritunl
from pritunl_api.utils.query import org_user
from pritunl_api.utils.keygen import profile_key

from .cloud_vendor import check_serverless
if check_serverless() == 'aws-lambda':
    from .cloud_vendor.aws.secretsmanager import get_secret

    app = App(
        process_before_response = True,
        signing_secret = get_secret(os.environ['SLACK_SIGNING_SECRET']),
        token = get_secret(os.environ['SLACK_BOT_TOKEN'])
    )

    pritunl = Pritunl(
        url = get_secret(os.environ['PRITUNL_BASE_URL']),
        secret = get_secret(os.environ['PRITUNL_API_SECRET']),
        token = get_secret(os.environ['PRITUNL_API_TOKEN'])
    )

else:
    app = App()
    pritunl = Pritunl()


@app.middleware
def log_request(logger, body, next):
    logger.debug(body)
    return next()


def validate_command(body):
    command_args = body.get("text")
    if command_args is None or len(command_args) == 0:
        return False
    else:
        command = command_args.split()
        if len(command) == 2:
            if command[0] and command[1]:
                return True
            else:
                return False
        else:
            return False


def initial_acknowledgement(body, ack):
    def command_usage():
        return str(f"*:book: Usage:* `{body['command']} profile-key [ORGANIZATION]`")

    def command_accepted():
        return str(f"*:ballot_box_with_check: Request Accepted:* `{' '.join([body['command'], body['text']])}`")

    ack(command_accepted() if validate_command(body) else command_usage())


def processing_request(respond, body):
    if validate_command(body):
        respond(f"Hi <@{body['user_id']}>, please kindly wait while we process your request.")

        command = body.get("text").split()

        if 'api' in command[0] and 'status' in command[1]:
            # Undocumented feature, hidden from the command usage for administrative and diagnostic purposes.
            respond(f"```{json.dumps(pritunl.status(), indent=2)}```")

        elif 'profile-key' in command[0]:
            org_name = command[1]
            user_name = body['user_name']
            user_email = app.client.users_info(user=body['user_id'])['user']['profile']['email']
            user_pin = ''.join(choice(string.digits) for _ in range(6))

            user_data = {
                'name' : user_name,
                'email' : user_email,
                'pin' : user_pin,
            }

            org, user = org_user(pritunl=pritunl, org_name=org_name, user_name=user_name)

            if user:
                respond(f"Your profile already exists! \nUpdating your profile with new PIN.")
                update = pritunl.user.put(
                    org_id=org['id'],
                    usr_id=user['id'],
                    data=user_data
                    )

                if update:
                    key_uri_url, key_view_url = profile_key(pritunl=pritunl, org_id=update['organization'], usr_id=update['id'])

                    respond_line = [
                        f"\n",
                        f":ballot_box_with_check: We Succesfully updated your VPN profile `{update['name']}` under the network organization `{update['organization_name']}`. \n",
                        f"\n",
                        f"Here is your newly recreated *Profile Key*: `{key_uri_url}` \n",
                        f"And your *Connection PIN*: `{user_data['pin']}` \n",
                        f" \n",
                        f"_For other connection options, kindly open the <{key_view_url}|profile link>_. \n",
                        f"_Such as *Changing PIN* or *Download a Profile Key* for other OS_. \n"
                        f"_Take note that *Profile Key* links will expire after 24 hours_.",
                    ]
                    respond(" ".join(respond_line))

            else:
                respond(f"VPN profile creation is in progress. \nWhile waiting, please download the VPN <https://client.pritunl.com/#install|client> if you do not already have installed.")
                create_user = pritunl.user.post(
                    org_id=org['id'],
                    data=user_data
                    )

                if create_user:
                    for user in create_user:
                        key_uri_url, key_view_url = profile_key(pritunl=pritunl, org_id=user['organization'], usr_id=user['id'])

                        respond_line = [
                            f"\n",
                            f":ballot_box_with_check: We successfully created your VPN profile `{user['name']}` under the organization `{user['organization_name']}`. \n",
                            f" \n",
                            f"Here is your newly created *Profile Key*: `{key_uri_url}` \n",
                            f"And your *Connection PIN*: `{user_data['pin']}` \n",
                            f" \n",
                            f"_For other connection options, kindly open the <{key_view_url}|profile link>_. \n",
                            f"_Such as *Changing PIN* or *Download a Profile Key* for other OS_. \n"
                            f"_Take note that *Profile Key* links will expire after 24 hours_.",
                        ]
                        respond(" ".join(respond_line))


app.command("/pritunl")(
    ack=initial_acknowledgement,
    lazy=[processing_request]
)
