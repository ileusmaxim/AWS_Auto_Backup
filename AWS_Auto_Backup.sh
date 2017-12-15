#!/bin/sh
DATE_CURRENT=`date +%Y-%m-%d`
TIME_CURRENT=`date +%Y%m%d%H%M%S`
PURGE_AFTER_DAYS=7
PURGE_AFTER=`date -d +${PURGE_AFTER_DAYS}days -u +%Y-%m-%d`
 
# 1-1.Отримати список ресурсів, для якого потрібно створити резервну копію
INSTANCES=`aws ec2 describe-tags --filters "Name=resource-type,Values=instance" "Name=key,Values=Backup" | awk '{print $3}'`
 
for INSTANCE in ${INSTANCES}; do
 
  BACKUP=`aws ec2 describe-tags --filters "Name=resource-type,Values=instance" "Name=resource-id,Values=${INSTANCE}" "Name=key,Values=Backup" | awk '{print $5}'`
 
  # 1-2.Перевірте тег, щоб побачити, чи це резервна ціль
  if [ "${BACKUP}" == "true" ]; then
 
    # 1-3.Створити резервну копію
    AMI_ID=`aws ec2 create-image --instance-id ${INSTANCE} --name "${INSTANCE}_${TIME_CURRENT}" --no-reboot`
 
    # 1-4.Створіть тег, який використовуватиметься для пошуку
    aws ec2 create-tags --resources ${AMI_ID} --tags Key=PurgeAllow,Value=true Key=PurgeAfter,Value=$PURGE_AFTER
  fi
done
 
# 2-1.Шукайте резервні копії, які можна видалити тегами як умови
AMI_PURGE_ALLOWED=`aws ec2 describe-tags --filters "Name=resource-type,Values=image" "Name=key,Values=PurgeAllow" | awk '{print $3}'`
 
for AMI_ID in ${AMI_PURGE_ALLOWED}; do
  PURGE_AFTER_DATE=`aws ec2 describe-tags --filters "Name=resource-type,Values=image" "Name=resource-id,Values=${AMI_ID}" "Name=key,Values=PurgeAfter"  | awk '{print $5}'`
 
  if [ -n ${PURGE_AFTER_DATE} ]; then
    DATE_CURRENT_EPOCH=`date -d ${DATE_CURRENT} +%s`
    PURGE_AFTER_DATE_EPOCH=`date -d ${PURGE_AFTER_DATE} +%s`
 
    if [[ ${PURGE_AFTER_DATE_EPOCH} < ${DATE_CURRENT_EPOCH} ]]; then
      # 2-2.Дивлячись на тег судить, чи це ціль делеції, і якщо це ціль, видаляє резервну копію
      aws ec2 deregister-image --image-id ${AMI_ID}
       
      SNAPSHOT_ID=`aws ec2 describe-images --image-ids ${AMI_ID} | grep EBS | awk '{print $4}'`
      aws ec2 delete-snapshot --snapshot-id ${SNAPSHOT_ID}
    fi
  fi
done

 COL_Green="\x1b[32;01m"
 COL_Yellow="\x1b[33;01m"
 COL_RESET="\x1b[39;49;00m"

 echo -e $COL_Green" $DATE_CURRENT_EPOCH "$COL_RESET""
 echo -e $COL_Yellow" $PURGE_AFTER_DATE_EPOCH "$COL_RESET""


