This repo uses kafkacat to execute cycles of heartbeats by producing messages into a Kafka cluster to check that all brokers are responsive. It is useful in scenarios where a canary monitoring service is needed to check cluster health, independantly of the primary monitoring console.
It uses docker-compose to stand up containers, shell scripts to execute logic, kafkacat to produce messages, influxDB to store results and a Grafana dashboard to visualize heartbeat status.
The shell scripts can be edited to redirect the heartbeat cycle to any Kafka cluster. 


Quickstart
start docker with at least 8GB RAM
docker-compose up
Browse to localhost:9021 (Control Center) to confirm 
1/ Six brokers up
2/ Heartbeat topic with six partition
3/ Confirm that partition leader alignment = broker id (partition 1 leader on broker 1 etc)
4/ "End Offset" is advancing for all partitions every 10 seconds

Browse to localhost:3000 (Grafana)
1/ Login as Admin/Admin
2/ At password chanhge prompt click "skip"
3/ Select Dashboards | Import | Import JSON File | Browse | Select "grafana.json"
4/ Select Data Sources | InfluxDB | Add | hostname = "http://influxdb:8086" | database = "telegraf" | Test & Save
5/ Select Dashboards | Kafka Heartbeat

why?
1/Confluent Control Centre depends on topics for state; when the topics are co-hosted with other application topics on a cluster that becomes unresponsive, then monitoring also becomes unresponsive.
2/ Kafka Monitoring apps (Control Center included) may be rack0-aware; but not necessarily topology aware so visualizing placement of brokers in data centers can be helpful for a canary-level depiction of the system state. This is particulaly important for stretched clusters where heartbeat failure for brokers 4,5,6 simultaneously may indicate that DC2 is down.  

Broker level tests
the heartbeat topic is created with partition (count) = broker (count) with the leader for each partition on its respectively numbered broker. Kafkacat produces a message into a nominated partition with acks=1 to confirm that the broker is online, and can complete a produce request. The elapsed time to produce one message is recorded in InfluxDB in case a degradation in response time becomes visible.

Docker
docker-compose stands up one zookeeper, six brokers, a Confluent Control center, InfluxDB, Grafana, Telegraf and a "Runme" container to start the shellscripts.

Kafkacat
A stripped down version of the wonderful Kafkacat is included; with the binary and the libs necessary to run the heartbeat (in scripts/lib). Kafkacat was chosen because of "-p" to produce into a specific parititon.
This is the command executed in scripts/pulse.sh:
kafkacat -b ${BROKER}:${PORT}  -t heartbeat -K: -p${PARTITION_ID} -T -P -X topic.request.required.acks=1
The message it produces is simply partitionId:timestamp.  pulse.sh captures the elpased time to execute the kafkacat produce command, which is posted to InfluxDB to be visualized on Grafana.

Heartbeats
The heartbeat cycles are executed by scripts/pulse.sh in ten second cycles (configurable). 

InfluxDB
Produce response times are stored in InfluxDB, pushed using a REST call to minimize dependancies. 

Telegraf
The docker-compose contains a container for Telegraf (and there is a directory which is mounted with telegraf scrape configs for Kafka services) however this is not implemented as the focus is heartbeat cycles; not monitoring.

Grafana
There are three layers of charts in Grafana: a single numeric metric for the produce ms/broker, a numeric metric for the number of heartbeats per broker (both for the prior 5 minute window) and produce ms/broker on a multi-series line chart, where each line depicts the broker response time for each heartbeat cycle. Metrics are polled from InfluxDB with thresholds to depict degraded (including dead) results in red. 

Replica Placement
scripts/create.sh creates the heartbeat topic with three replicas (to avoid alarming monitoring products), using replica-placement to ensure that the leader for partition-1 is on broker-1; leader for partition-2 is on broker-2 etc. 

JMX Metric collection for JVMs
See add_jolokia/README to reconfigure JVMs to add jolokia to expand metric collection for JVMs

Usage for other clusters
Make the following edits to run  heartbeats for another cluster
1/ [optional] edit docker-compose.yml and remove zookeeper, kafka and control-center containers
2/ edit scripts/create.sh to add login credentials and replica.placement to match the target broker count
3/ edit scripts/pulse.sh to align the target cluster broker count (default = 6)
4/ edit the Grafana dashboard to add/remove panes to match the desired broker count.

Troubleshooting
The log4j directory contains log4j config files for INFO, WARN and DEBUG. Edit docker-compose.yml to change the desired level and restart the container


