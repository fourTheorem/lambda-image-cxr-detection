ARG FUNCTION_DIR="/var/task"

# Install/build the AWS runtime client in the first stage
FROM python:3.8-buster AS build-image

RUN pip install awscli

ENV FUNCTION_DIR=/var/task

RUN mkdir -p /var/task
WORKDIR /var/task
RUN pip install awslambdaric --target /var/task

FROM cxr-bin-cls:latest
COPY src/ /var/task

COPY --from=build-image /var/task /var/task
WORKDIR /var/task

COPY src/requirements.txt /var/task
RUN pip install -r requirements.txt
COPY src/ /var/task
RUN chmod -R a-w /var/torch/

ENV PYTHONPATH=/src
ENTRYPOINT [ "/usr/local/bin/python", "-m", "awslambdaruntimeclient" ]
CMD ["handler.handle_event"]
