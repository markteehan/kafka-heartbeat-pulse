#!/bin/sh
# docker-compose suppresses "echo" for this script. Edit docker-compose.yml to see the stdout from this script
SLEEP=10
echo "========= Pulsing into topic heartbeat every five secs ===================="
    export PATH=/tmp/kafkacat:${PATH}
    export LD_LIBRARY_PATH=/tmp/kafkacat/lib:${LD_LIBRARY_PATH}
    while true
    do
      DT=`date +"%a %d-%b %H:%m:%S"`
      BROKERS="1 2 3 4 5 6"
      BROKERS="3 2"
      TIMEFORMAT="%R"
      for i in `echo ${BROKERS}`
      do
        PARTITION_ID=$(($i - 1 ))
        #as each leader lives on a known broker, only attempt to resolve that broker
        case "${i}" in 
        1)  BOOTSTRAP_SERVERS="kafka1:19091" ;;
        2)  BOOTSTRAP_SERVERS="kafka2:19092" ;;
        3)  BOOTSTRAP_SERVERS="kafka3:19093" ;;
        4)  BOOTSTRAP_SERVERS="kafka4:19094" ;;
        5)  BOOTSTRAP_SERVERS="kafka5:19095" ;;
        6)  BOOTSTRAP_SERVERS="kafka6:19096" ;;
        esac
        exec 3>&1 4>&2
        set -x
        RESULT=$($({ time echo "${i}:${DT}" | kafkacat -b ${BOOTSTRAP_SERVERS}  -t heartbeat -K: -p${PARTITION_ID} -T -P -X topic.request.required.acks=1  1>&3 2>&4  ;   }  2>&1 ) || true ) || true
        RESULT=$({ time echo "${i}:${DT}" | kafkacat -b ${BOOTSTRAP_SERVERS}  -t heartbeat -K: -p${PARTITION_ID} -T -P -X topic.request.required.acks=1  1>&3 2>&4  ;   }  2>&1 )

        #echo $RESULT | awk '{
        #  printf "%.3f \n", $1%60
        #}'
        exec 3>&- 4>&-
        #curl --silent --output /dev/null -i -XPOST 'http://influxdb:8086/write?db=telegraf' --data-binary "heartbeat,broker=${i},environment=prod value=${RESULT}"
        curl          --output /dev/null -i -XPOST 'http://influxdb:8086/write?db=telegraf' --data-binary "heartbeat,broker=${i},environment=prod value=${RESULT}"
      done
      sleep ${SLEEP}
    done

