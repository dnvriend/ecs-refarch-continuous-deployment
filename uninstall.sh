#!/bin/bash
source settings.sh

deleteBucketVersions() {
    # install the commandline JSON processor
    brew install jq
    echo "Removing all versions from ${TEMPLATE_BUCKET}"
    versions=`aws s3api list-object-versions --bucket ${TEMPLATE_BUCKET} |jq '.Versions'`
    markers=`aws s3api list-object-versions --bucket ${TEMPLATE_BUCKET} |jq '.DeleteMarkers'`
    let count=`echo $versions |jq 'length'`-1

    if [ $count -gt -1 ]; then
            echo "removing files"
            for i in $(seq 0 $count); do
                    key=`echo $versions | jq .[$i].Key |sed -e 's/\"//g'`
                    versionId=`echo $versions | jq .[$i].VersionId |sed -e 's/\"//g'`
                    cmd="aws s3api delete-object --bucket ${TEMPLATE_BUCKET} --key $key --version-id $versionId"
                    echo $cmd
                    $cmd
            done
    fi

    let count=`echo $markers |jq 'length'`-1

    if [ $count -gt -1 ]; then
            echo "removing delete markers"

            for i in $(seq 0 $count); do
                    key=`echo $markers | jq .[$i].Key |sed -e 's/\"//g'`
                    versionId=`echo $markers | jq .[$i].VersionId |sed -e 's/\"//g'`
                    cmd="aws s3api delete-object --bucket ${TEMPLATE_BUCKET} --key $key --version-id $versionId"
                    echo $cmd
                    $cmd
            done
    fi
}

deleteBucket() {
    aws s3 rb "s3://${TEMPLATE_BUCKET}" --force
}

echo "Deleting the bucket"
deleteBucketVersions
aws s3api delete-bucket --bucket ${TEMPLATE_BUCKET}
echo "Deleting stack: ${STACK_NAME}"
aws cloudformation delete-stack --stack-name ${STACK_NAME}
echo "Waiting for stack deletion"
aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME}
echo "Done"