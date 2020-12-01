PARENT = $(shell dirname $(PWD))
REGION = sa-east-1
APP_NAME = cxr-prediction
CF_STACK_ARGS = --region $(REGION) --stack-name $(APP_NAME) --template-body file:///$(PWD)/template.yml --capabilities CAPABILITY_NAMED_IAM
ACCOUNT_ID = $(shell aws sts get-caller-identity --query Account --output text)
REPOSITORY_URI = $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/$(APP_NAME)
LAMBDA_ROLE_ARN = arn:aws:iam::$(ACCOUNT_ID):role/cxr-prediction-handler-role
FUNCTION_NAME = cxr-prediction
FUNCTION_TIMEOUT = 180
DLQ_ARN=arn:aws:sqs:$(REGION):$(ACCOUNT_ID):cxrPredictionDLQ
FUNCTION_CONFIG = --environment "Variables={BUCKET_NAME=$(BUCKET_NAME),MODEL_PATH=/src/trained_models_nih}" --function-name $(FUNCTION_NAME) --memory-size 512 --role $(LAMBDA_ROLE_ARN) --timeout $(FUNCTION_TIMEOUT) --dead-letter-config "TargetArn=$(DLQ_ARN)"
all: test-local

ecr-login-runtimes:
	aws ecr get-login-password --region sa-east-1 | docker login --username AWS --password-stdin 628053151772.dkr.ecr.sa-east-1.amazonaws.com

python-image: ecr-login-runtimes
	docker pull 628053151772.dkr.ecr.sa-east-1.amazonaws.com/awslambda/python3.8-runtime:beta

nodejs-image: ecr-login-runtimes
	docker pull 628053151772.dkr.ecr.sa-east-1.amazonaws.com/awslambda/nodejs12.x-runtime:beta

pull: python-image

build:
	docker build -t $(APP_NAME) .
	docker tag $(APP_NAME) $(REPOSITORY_URI):latest

push: build
	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com
	docker push $(REPOSITORY_URI):latest

update-stack:
	aws cloudformation update-stack $(CF_STACK_ARGS)

create-stack:
	aws cloudformation create-stack $(CF_STACK_ARGS)

stack-status:
	aws cloudformation describe-stacks --region $(REGION) --stack-name=$(APP_NAME) --query "Stacks[0]" --output table

create-function:
	aws lambda --region $(REGION) create-function $(FUNCTION_CONFIG) \
		--code ImageUri=$(REPOSITORY_URI):latest \
		--package-type Image

update-function-config:
	aws lambda --region $(REGION) update-function-configuration $(FUNCTION_CONFIG)

update-function-code:
	aws lambda --region $(REGION) update-function-code \
		--function-name $(FUNCTION_NAME) \
		--image-uri $(REPOSITORY_URI):latest  \
		--publish

delete-function:
	aws lambda --region $(REGION) delete-function \
		--function-name $(FUNCTION_NAME)

invoke:
	aws lambda --region $(REGION) invoke --function-name $(FUNCTION_NAME) \
		--invocation-type RequestResponse --payload '$(shell cat test-events/single-job.json | base64)' /tmp/response.json

run-local: build kill-local
	docker run --name $(APP_NAME)-local -d \
		-e BUCKET_NAME=$(BUCKET_NAME) \
		-e MODEL_PATH=/src/trained_models_nih \
		-e AWS_PROFILE=$(AWS_PROFILE) \
		-v $(HOME)/.aws:/root/.aws \
		-v $(PARENT)/emulator/LambdaImageBeta/local-lambda-runtime-server:/opt/local-lambda-runtime-server \
		-p 9000:8080 --entrypoint /opt/local-lambda-runtime-server/aws-lambda-local $(APP_NAME):latest \
		/usr/local/bin/python -m awslambdaruntimeclient \
		handler.handle_event
	sleep 2

invoke-local: run-local
	curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d @test-events/single-job.json
	docker logs $(APP_NAME)-local

kill-local:
	-docker rm -f $(APP_NAME)-local 2>&1 > /dev/null

