#!/bin/bash
source settings.sh

createBucket() {
    set -o errexit -o xtrace
    echo "Creating bucket: s3://${TEMPLATE_BUCKET}"
    aws s3api head-bucket --bucket "${TEMPLATE_BUCKET}" || aws s3 mb "s3://${TEMPLATE_BUCKET}" --region ${AWS_REGION}
    sleep 2 # sleeping 2 seconds for eventual consistency
    echo "Setting bucket policy"
    aws s3api put-bucket-policy --bucket "${TEMPLATE_BUCKET}" \
        --policy "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":[\"s3:GetObject\",\"s3:GetObjectVersion\"],\"Resource\":\"arn:aws:s3:::${TEMPLATE_BUCKET}/*\"},{\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":[\"s3:ListBucket\",\"s3:GetBucketVersioning\"],\"Resource\":\"arn:aws:s3:::${TEMPLATE_BUCKET}\"}]}"
    aws s3api put-bucket-versioning --bucket "${TEMPLATE_BUCKET}"  --versioning-configuration Status=Suspended
    echo "Uploading file: ecs-refarch-continuous-deployment.yaml to bucket"
    aws s3 cp ecs-refarch-continuous-deployment.yaml "s3://${TEMPLATE_BUCKET}"
    echo "Recursively copying templates to bucket"
    aws s3 cp --recursive templates/ "s3://${TEMPLATE_BUCKET}/templates"
}

createBucket

echo "Creating stack ${STACK_NAME}"
aws cloudformation create-stack \
    --stack-name ${STACK_NAME} \
    --capabilities CAPABILITY_IAM \
    --template-body file://ecs-refarch-continuous-deployment.yaml \
    --parameters ParameterKey=GitHubToken,ParameterValue="${GITHUB_TOKEN}" \
                 ParameterKey=GitHubRepo,ParameterValue=${GITHUB_REPO} \
                 ParameterKey=GitHubUser,ParameterValue=${GITHUB_USER} \
                 ParameterKey=GitHubBranch,ParameterValue=${GITHUB_BRANCH} \
                 ParameterKey=TemplateBucket,ParameterValue=${TEMPLATE_BUCKET} \
                 ParameterKey=LaunchType,ParameterValue=${ECS_LAUNCH_TYPE}

echo "Waiting for stack creation complete"
aws cloudformation wait stack-create-complete --stack-name ${STACK_NAME}
echo "Done"