#!/usr/bin/env bash

function configure_awscli_keys() {
  KEY_ID=$1
  SECRET_KEY=$2
  aws configure set aws_access_key_id $KEY_ID --profile $PROFILE
  aws configure set aws_secret_access_key $SECRET_KEY --profile $PROFILE
}

function configure_awscli_region() {
  SOURCE_BUCKET=$1
  TARGET_BUCKET=$2

  SOURCE_REGION=$(aws s3api get-bucket-location --output text --profile "source" --bucket $SOURCE_BUCKET)
  TARGET_REGION=$(aws s3api get-bucket-location --output text --profile "target" --bucket $TARGET_BUCKET)
  aws configure set region $SOURCE_REGION --profile "source"
  aws configure set region $TARGET_REGION --profile "target"
}

function configure_awscli_s3() {
  MAX_REQUESTS=${1:-20}
  MAX_QUEUE_SIZE=${2:-10000}
  MULTIPART_THRESHOLD=${3:-"64MB"}
  MULTIPART_CHUNKSIZE=${4:-"16MB"}

  aws configure set default.s3.max_concurrent_requests $MAX_REQUESTS
  aws configure set default.s3.max_queue_size $MAX_QUEUE_SIZE
  aws configure set default.s3.multipart_threshold $MULTIPART_THRESHOLD
  aws configure set default.s3.multipart_chunksize $MULTIPART_CHUNKSIZE
}

function setup_lvm() {
  DISKS=$1
  PATH=${2:-"/data"}
  FIRST=1
  for dsk in $DISKS; do
    [ -b "/dev/$dsk" ] && pvcreate "/dev/$dsk"

    if (( $FIRST == 1 )); then
      vgcreate vgdata "/dev/$dsk"
      FIRST=0
    else
      vgextend vgdata "/dev/$dsk"
    fi
  done

  mkdir $PATH
  lvcreate -l 100%FREE -n lvdata vgdata
  mkfs.ext4 /dev/vgdata/lvdata
  mount /dev/vgdata/lvdata $PATH
}

IAM_CONFIG=$1
shift

SOURCE_BUCKET=$1
TARGET_BUCKET=$2
DISKS=$3
SOURCE_PATH=$4
TARGET_PATH=$5

if [ "$IAM_CONFIG" = "iam_source "]; then
  configure_awscli_keys $KEY_ID $SECRET_KEY "target"
elif [ "$IAM_CONFIG" = "iam_target" ]; then
  configure_awscli_keys $KEY_ID $SECRET_KEY "source"
else
  configure_awscli_keys $SOURCE_KEY_ID $SOURCE_SECRET_KEY "source"
  configure_awscli_keys $TARGET_KEY_ID $TARGET_SECRET_KEY "target"
fi

configure_awscli_s3
configure_awscli_region $SOURCE_BUCKET $TARGET_BUCKET

setup_lvm $DISKS

aws s3 sync --profile "source" s3://$SOURCE_BUCKET/$SOURCE_PATH $LOCAL_PATH
echo "Listing downloaded files"
find $LOCAL_PATH | tee /data/s3sync_manifest.txt
aws s3 sync --profile "target" $LOCAL_PATH s3://$TARGET_BUCKET/$TARGET_PATH
