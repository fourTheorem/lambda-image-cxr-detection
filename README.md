# AWS Lambda Image Container Chest X-Ray Example

This is a deep learning in AWS Lambda example application. It demonstrates functions deployed as *Image Containers*!
It can be used as a reference for Lambda Functions based on existing base images.

The base image is built on the Chest X-Ray Binary Classifier [1] developed by Yuxing Tang (yuxing.tang@nih.gov), Imaging Biomarkers and Computer-Aided Diagnosis Laboratory, National Institutes of Health (NIH) Clinical Center. The base image (https://github.com/eoinsha/CADLab/tree/master/CXR-Binary-Classifier) is forked from https://github.com/rsummers11/CADLab.

The training and test image data used is the [NIH Chest X-ray Dataset of 14 Common Thorax Disease Categories](https://nihcc.app.box.com/v/ChestXray-NIHCC). [2]

## Preparation

The image data (linked above) should be copied to an S3 bucket in the following layout.

```
2020-11-14 21:40:50     457171 cxr-nih/images_01/images/00000001_000.png
2020-11-14 21:40:50     444655 cxr-nih/images_01/images/00000001_001.png
2020-11-14 21:40:50     351772 cxr-nih/images_01/images/00000001_002.png
2020-11-14 21:40:50     402332 cxr-nih/images_01/images/00000002_000.png
2020-11-14 21:40:50     450000 cxr-nih/images_01/images/00000003_000.png
2020-11-14 21:40:50     383773 cxr-nih/images_01/images/00000003_001.png
2020-11-14 21:40:50     343273 cxr-nih/images_01/images/00000003_002.png
2020-11-14 21:40:50     456605 cxr-nih/images_01/images/00000003_003.png
2020-11-14 21:40:50     371185 cxr-nih/images_01/images/00000003_004.png
2020-11-14 21:40:50     437334 cxr-nih/images_01/images/00000003_005.png
```

In our tests, we used the full set of test and training data (120,000+) images but a subset will do fine.


## Build and Deployment

Currently, a Makefile is used to create the ECR repository and publish the container image. It is also used to create the container image-based Lambda function. The Serverless Framework-based stack is used for deployment of the other resources and orchestrating functions.

First, check the `Makefile` and edit the
1. `export BUCKET_NAME=<your_bucket>`
2. `npm install`
3. `make create-stack`
4. `make push`
5. `make create-function`
6. `npm run sls -- deploy --region=<region>`


## Running
Invoke the `createJobs` Lambda function (Defined in [serverless.yml](./serverless.yml)] with a test input (choose any from [test-events/](./test-events)).

This will create batches of records on a Kinesis stream which are used to invoke the image-based Lambda concurrently, resulting in a potentially large number of concurrent invocations.

Prediction results are stored in DynamoDB.


## References
1. Automated abnormality classification of chest radiographs using deep convolutional neural networks, Yu-Xing Tang, You-Bao Tang, Yifan Peng, Ke Yan and Mohammadhadi Bagheri, Bernadette A Redd, Catherine J Brandon, Zhiyong Lu, Mei Han, Jing Xiao, and Ronald M Summers, npj Digital Medicine, 2020
2. Chestx-ray8: Hospital-scale chest x-ray database and benchmarks on weakly-supervised classification and localization of common thorax diseases, Xiaosong Wang, Yifan Peng, Le Lu, Zhiyong Lu, Mohammadhadi Bagheri, and Ronald M Summers, Proceedings of the IEEE conference on computer vision and pattern recognition, 2017

