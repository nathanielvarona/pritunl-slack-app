ARG RUNTIME_VERSION=3.10.7
ARG DISTRO_VERSION=slim-buster
ARG FUNCTION_DIR=/function

#
# Stage: build
#
FROM python:${RUNTIME_VERSION}-${DISTRO_VERSION} AS build-image

ARG POETRY_VERSION=1.8.2
ARG APP_NAME=pritunl_slack_app
ARG APP_PATH=/opt/${APP_NAME}
ARG FUNCTION_DIR

ENV \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1

ENV \
    POETRY_VERSION=${POETRY_VERSION} \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1

ENV \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100

ARG \
    AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"us-east-1"} \
    AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-""} \
    AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-""}

ENV \
    AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} \
    AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
    AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

RUN apt-get update && \
    apt-get install -y \
        curl \
        unzip \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="$POETRY_HOME/bin:$PATH"

WORKDIR ${APP_PATH}
COPY ./poetry.lock ./pyproject.toml ./README.md ./
COPY ./${APP_NAME} ./${APP_NAME}

RUN poetry build --format wheel
RUN pip install poetry-plugin-export
RUN poetry export --extras aws \
    --without-hashes \
    --format requirements.txt \
    --output constraints.txt

RUN mkdir -p ${FUNCTION_DIR}

RUN curl \
    $(aws lambda get-layer-version-by-arn --arn arn:aws:lambda:us-east-1:177933569100:layer:AWS-Parameters-and-Secrets-Lambda-Extension:4 --query 'Content.Location' --output text) \
    --output layer.zip && \
    unzip layer.zip -d /opt && \
    rm layer.zip

RUN python -m pip install \
    awslambdaric \
    --target ${FUNCTION_DIR}

RUN python -m pip install --find-links=dist/ pritunl_slack_app[aws] \
    --constraint constraints.txt \
    --target ${FUNCTION_DIR}

#
# Stage: production
#
FROM python:${RUNTIME_VERSION}-${DISTRO_VERSION}

ARG FUNCTION_DIR

WORKDIR ${FUNCTION_DIR}

COPY --from=build-image /opt/extensions /opt/extensions
COPY --from=build-image ${FUNCTION_DIR} ${FUNCTION_DIR}

ENTRYPOINT [ "/usr/local/bin/python", "-m", "awslambdaric" ]
CMD [ "pritunl_slack_app.function.pritunl_slack_app.function_handler.handler" ]
