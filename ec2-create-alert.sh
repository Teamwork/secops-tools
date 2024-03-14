#!/usr/bin/env bash
NOW_MINUS_5MIN=$(date -u --date='120 minutes ago')
NOW_MINUS_5MIN_EPOCH=$(date -d"$NOW_MINUS_5MIN" +%s)

EVENT_COUNT=$(aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=RunInstances --start-time $NOW_MINUS_5MIN_EPOCH --profile $1 --output json | jq '.Events' | jq '. | length')
echo $EVENT_COUNT
if [ "$EVENT_COUNT" = "0" ]
then
   exit 0;
fi

if [ "$1" = "stg" ]
then
    ACCOUNT="Staging"
elif [ "$1" = "prod" ]
then
    ACCOUNT="Production"
else
    ACCOUNT="$1"
fi
EVENT_COUNT=$((EVENT_COUNT-1))
echo $EVENT_COUNT
for i in $(eval echo "{$EVENT_COUNT..0}")
do
    DATA=`aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=RunInstances --start-time $NOW_MINUS_5MIN_EPOCH --profile $1 --output json | jq .Events[$i]`

    EVENTID=`echo $DATA | jq '.EventId' | sed 's/"//g'`
    touch /tmp/events.log

    if grep -q "$EVENTID" /tmp/events.log; then
        continue
    fi

    USERAGENT=`echo $DATA | jq '.Username' | sed 's/"//g'`
    echo $USERAGENT
    if [[ "$USERAGENT" == *"AutoScaling"* ]]; then
        continue
    fi

    #Get username from event
    USERNAME=`echo $DATA | jq '.Username' | sed 's/"//g'`


    #Convert event time to user friendly format
    LOGINTIMEISO=$(echo $DATA | jq '.CloudTrailEvent' | sed 's/\\//g' | sed -e 's/^"//' -e 's/"$//' | jq .eventTime | sed -e 's/^"//' -e 's/"$//')
    LOGINTIMEEPOCH=$(date -d"$LOGINTIMEISO" +%s)
    LOGINTIMEFRIENDLY=$(date -d @$LOGINTIMEEPOCH)



    #Get IP address user logged in from and create whoislink
    SOURCEIPADDRESS=$(echo $DATA | jq '.CloudTrailEvent' | sed 's/\\//g' | sed -e 's/^"//' -e 's/"$//' | jq .sourceIPAddress | sed -e 's/^"//' -e 's/"$//')
    WHOISLINK="https://who.is/whois-ip/ip-address/${SOURCEIPADDRESS}"
    #echo $DATA | jq '.CloudTrailEvent' | sed 's/\\//g' | sed -e 's/^"//' -e 's/"$//' | jq .
    AWSREGION=$(echo $DATA | jq '.CloudTrailEvent' | sed 's/\\//g' | sed -e 's/^"//' -e 's/"$//' | jq .awsRegion | sed -e 's/^"//' -e 's/"$//')
    InstanceType=$(echo $DATA | jq '.CloudTrailEvent' | sed 's/\\//g' | sed -e 's/^"//' -e 's/"$//' | jq .requestParameters.instanceType | sed -e 's/^"//' -e 's/"$//')
    InstanceID=$(echo $DATA | jq '.CloudTrailEvent' | sed 's/\\//g' | sed -e 's/^"//' -e 's/"$//' | jq .responseElements.instancesSet.items | jq ".[0].instanceId" | sed -e 's/^"//' -e 's/"$//')
    PrivateIP=$(echo $DATA | jq '.CloudTrailEvent' | sed 's/\\//g' | sed -e 's/^"//' -e 's/"$//' | jq .responseElements.instancesSet.items | jq ".[0].privateIpAddress" | sed -e 's/^"//' -e's/"$//')
    PublicIPAssociated=$(echo $DATA | jq '.CloudTrailEvent' | sed 's/\\//g' | sed -e 's/^"//' -e 's/"$//' | jq .requestParameters.networkInterfaceSet.items[0].associatePublicIpAddress | sed -e 's/^"//' -e 's/"$//')

    #Convert event time to user friendly format

    ## Create message content and formatting
    MESSAGE="**:new:EC2 Created in AWS $ACCOUNT Account**\n
    **Username:**           ${USERNAME}\n
    **IP Address:**         ${SOURCEIPADDRESS} - [Lookup IP Address](<$WHOISLINK>)\n
    **Time:**               ${LOGINTIMEFRIENDLY}\n
    **AWS Region:**         ${AWSREGION}  \n
    **Instance Type:**      ${InstanceType}  \n
    **Public IP:**          ${PublicIPAssociated}  \n
    **Instance ID:**        ${InstanceID}  \n
    **Private IP:**         ${PrivateIP}  \n
    "
    echo $MESSAGE

    /home/ubuntu/chat-post.sh "$MESSAGE"
    echo $EVENTID >> /tmp/events.log
done
exit 0;