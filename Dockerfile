ARG APP_NAME=pritunl_slack_app
ARG APP_PATH=/opt/${APP_NAME}
ARG PYTHON_VERSION=3.10.7
ARG POETRY_VERSION=1.4.2
ARG APP_PORT=9000

#
# Stage: staging
#
FROM python:${PYTHON_VERSION} as staging
ARG APP_NAME
ARG APP_PATH
ARG POETRY_VERSION

ENV \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1
ENV \
    POETRY_VERSION=${POETRY_VERSION} \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1

RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/install-poetry.py | python
ENV PATH="$POETRY_HOME/bin:$PATH"

WORKDIR ${APP_PATH}
COPY ./poetry.lock ./pyproject.toml ./README.md ./
COPY ./${APP_NAME} ./${APP_NAME}

#
# Stage: development
#
FROM staging as development
ARG APP_NAME
ARG APP_PATH
ARG APP_PORT

WORKDIR ${APP_PATH}
RUN poetry install --extras flask

ENV FLASK_APP=${APP_NAME}/flask_handler.py \
    FLASK_DEBUG=True \
    FLASK_RUN_HOST=0.0.0.0 \
    FLASK_RUN_PORT=${APP_PORT}

ENTRYPOINT ["poetry", "run"]
CMD ["flask", "run"]

#
# Stage: build
#
FROM staging as build
ARG APP_PATH

WORKDIR ${APP_PATH}
RUN poetry build --format wheel
RUN poetry export --extras flask --format requirements.txt --output constraints.txt --without-hashes

#
# Stage: production
#
FROM python:${PYTHON_VERSION} as production
ARG APP_NAME
ARG APP_PATH
ARG APP_PORT

ENV \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1

ENV \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100

WORKDIR ${APP_PATH}
COPY --from=build ${APP_PATH}/dist/*.whl ./
COPY --from=build ${APP_PATH}/constraints.txt ./
RUN pip install --find-links=./ ${APP_NAME}[flask] --constraint constraints.txt

ENV APP_NAME=${APP_NAME}
ENV APP_PORT=${APP_PORT}

COPY ./docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["gunicorn", "--bind :${APP_PORT}", "--workers 1", "--threads 1", "--timeout 0", "\"${APP_NAME}.flask_handler:flask_app\""]
