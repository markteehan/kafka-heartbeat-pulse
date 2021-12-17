#!/bin/bash
# dec-12 added nc -z becuase if the broker is not reachable the non-zero kafkacat return status halts script execution
# docker-compose suppresses "echo" for this script. Edit docker-compose.yml to see the stdout from this script
SLEEP=10
echo "========= Pulsing into topic heartbeat every five secs ===================="
    export PATH=/tmp/kafkacat:${PATH}
    export LD_LIBRARY_PATH=/tmp/kafkacat/lib:${LD_LIBRARY_PATH}
    while true
    do
      DT=`date +"%a %d-%b %H:%m:%S"`
      BROKERS="1 2 3 4 5 6"
      BROKERS="6 5 4 3 2 1"
      TIMEFORMAT="%R"
      for i in `echo ${BROKERS}`
      do
        PARTITION_ID=$(($i - 1 ))
        #as each leader lives on a known broker, only attempt to resolve that broker
        case "${i}" in 
        1)  BROKER="kafka1" ; PORT="19091" ;;
        2)  BROKER="kafka2" ; PORT="19092" ;;
        3)  BROKER="kafka3" ; PORT="19093" ;;
        4)  BROKER="kafka4" ; PORT="19094" ;;
        5)  BROKER="kafka5" ; PORT="19095" ;;
        6)  BROKER="kafka6" ; PORT="19096" ;;
        esac

        # check if the broker hostname is reachable before getting into a complicated returnCode+BashScript situation.
        nc -z ${BROKER} ${PORT} 2>/dev/null
        RET=$?
        if [ "$RET" = 0 ]
        then
           exec 3>&1 4>&2
           RESULT=$({ time echo "${i}:${DT}" | kafkacat -b ${BROKER}:${PORT}  -t heartbeat -K: -p${PARTITION_ID} -T -P -X topic.request.required.acks=1 1>&3 2>&4; } 2>&1 ) 
           exec 3>&- 4>&-
           curl --silent --output /dev/null -i -XPOST 'http://influxdb:8086/write?db=telegraf' --data-binary "heartbeat,broker=${i},environment=prod value=${RESULT}"
        else
           echo "ERROR: broker $BROKER is not reachable on port ${PORT}!  (kafka heartbeat)"
        fi
      done
      sleep ${SLEEP}
    done

