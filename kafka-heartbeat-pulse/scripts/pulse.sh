#!/bin/bash
# dec-12 added nc -z becuase if the broker is not reachable the non-zero kafkacat return status halts script execution
# dec-18 avoid slow kafkacat response time by bootstrapping to broker1 for all pulses; and only tru kafka2 if kafka1 is unreachable (etc)
# docker-compose suppresses "echo" for this script. Edit docker-compose.yml to see the stdout from this script
SLEEP=10

BROKER_COUNT=6
BROKER_1_ID=1 ; BROKER_1_NAME=kafka1 ; BROKER_1_PORT=19091
BROKER_2_ID=2 ; BROKER_2_NAME=kafka2 ; BROKER_2_PORT=19092
BROKER_3_ID=3 ; BROKER_3_NAME=kafka3 ; BROKER_3_PORT=19093
BROKER_4_ID=4 ; BROKER_4_NAME=kafka4 ; BROKER_4_PORT=19094
BROKER_5_ID=5 ; BROKER_5_NAME=kafka5 ; BROKER_5_PORT=19095
BROKER_6_ID=6 ; BROKER_6_NAME=kafka6 ; BROKER_6_PORT=19096

    echo "========= Pulsing into topic heartbeat every ${SLEEP} secs ===================="
    export PATH=/tmp/kafkacat:${PATH}
    export LD_LIBRARY_PATH=/tmp/kafkacat/lib:${LD_LIBRARY_PATH}
    while true
    do
      DT=`date +"%a %d-%b %H:%m:%S"`
      TIMEFORMAT="%R"

      for i in $(seq 1 $BROKER_COUNT)
      do
        PARTITION_ID=$(($i - 1 ))
        BROKER_ID="BROKER_${i}_ID"

        # Always attempt to bootstrap from broker id=1. Kafkacat prefers this.
        BROKER_NAME="BROKER_1_NAME"
        BROKER_PORT="BROKER_1_PORT"
        # check if the broker hostname is reachable before getting into a complicated returnCode+BashScript situation.
        nc -z ${!BROKER_NAME} ${!BROKER_PORT} 2>/dev/null
        RET=$?
        if [ "$RET" -gt 0 ]
        then
          UNREACHABLE_BROKER_ID=${!BROKER_ID}
          # Broker_1 was unreahable. Try the others in sequence.
          for j in $(seq 2 $BROKER_COUNT)
           do
             BROKER_ID="BROKER_${j}_ID"
             BROKER_NAME="BROKER_${j}_NAME"
             BROKER_PORT="BROKER_${j}_PORT"
             nc -z ${!BROKER} ${!PORT} 2>/dev/null
             RET=$?
             if [ "$RET" -gt 0 ]
             then
               echo "Broker id=${UNREACHABLE_BROKER_ID} unreachable. Attempt to connect to broker id=${!BROKER_ID} : fail (return code ${RET})"
             else
               echo "Broker id=${UNREACHABLE_BROKER_ID} unreachable. Attempt to connect to broker id=${!BROKER_ID} : success"
             fi
           done
        else   # RET=0 so BROKER_1 is reachable
           exec 3>&1 4>&2
           START=`date +%s%N | cut -b1-13`
           RESULT=$({ echo "${i}:${DT}" | kafkacat -q -b ${!BROKER_NAME}:${!BROKER_PORT} -t heartbeat -K: -p${PARTITION_ID} -P -X topic.request.required.acks=1 1>&3 2>&4; } 2>&1 ) 
           END=`date +%s%N | cut -b1-13`
           ELAPSED_MS=$(($END - $START))
           exec 3>&- 4>&-
           curl --silent --output /dev/null -i -XPOST 'http://influxdb:8086/write?db=telegraf' --data-binary "heartbeat,broker=${i},environment=prod value=${ELAPSED_MS}"
           echo "Heartbeat: broker id=${!BROKER_ID} message pulsed into topic heartbeat partition id=${PARTITION_ID} in ${ELAPSED_MS} ms. bootstrap is ${!BROKER_NAME}:${!BROKER_PORT}"
        fi
      done
      sleep ${SLEEP}
    done

