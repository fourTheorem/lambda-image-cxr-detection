ARG FUNCTION_DIR="/var/task"

# Install/build the AWS runtime client in the first stage
FROM python:3.8-buster AS build-image

RUN pip install awscli

ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG AWS_SESSION_TOKEN
ARG AWS_PROFILE
ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
ENV AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN}
ENV FUNCTION_DIR=/var/task

RUN apt-get update && apt-get install -y cmake
RUN mkdir -p /var/task
WORKDIR /var/task
COPY awslambdaruntimeclient.tar.gz /root
RUN pip install /root/awslambdaruntimeclient.tar.gz --target /var/task

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
