#!/bin/sh
#
echo "========= Creating topic heartbeat                           ===================="
echo "kafka-topics --bootstrap-server kafka1:19091,kafka2:19092 --delete --topic heartbeat"
      kafka-topics --bootstrap-server kafka1:19091,kafka2:19092 --delete --topic heartbeat 2>/dev/null

     set -x
     kafka-topics --bootstrap-server kafka1:19091,kafka2:19092 --create --topic heartbeat --config cleanup.policy=delete --config retention.ms=3600000 --replica-assignment 1:2:3,2:3:4,3:4:5,4:5:6,5:6:1,6:1:2
    set +x
    echo " =================== "
    echo "Created a heartbeat topic with partition 1 leader on broker 1, partition 2 leader on broker 2 etc"
    echo " =================== "

