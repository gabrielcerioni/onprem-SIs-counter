#!/bin/bash

# This is a small function to deal with the fact that, even with --quiet, MongoDB output is full of trash on both stdout stderr
filter_mongodb_debug_messages() {
    # Workaround for https://jira.mongodb.org/browse/SERVER-27159
 
    grep -vE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}[+-][0-9]{4}\s+'
}


echo "THE QUERY AND HOST PROCESS STARTS HERE..."

${serviceVariable.SUDO_CMD} docker exec mongoContainer mongo "mongodb://${serviceVariable.admin_user}:${serviceVariable.admin_pass}@${serviceVariable.HOST1}:${serviceVariable.MONGODB_PORT},${serviceVariable.HOST2}:${serviceVariable.MONGODB_PORT},${serviceVariable.HOST3}:${serviceVariable.MONGODB_PORT}/harness?authSource=admin&replicaSet=${serviceVariable.replicaset_name}" --quiet --eval 'db.instance.find({isDeleted: false, infraMappingType: "PHYSICAL_DATA_CENTER_SSH"}, {"instanceInfo.hostName": 1, _id: 0}).toArray()' | filter_mongodb_debug_messages > input.json

jq -c '.[].instanceInfo.hostName' input.json | while read i; do
    #echo -n "Checking hostname $i..."
    host_to_validate=$(echo $i | tr -d '"')
    host $host_to_validate >>logger.txt 2>&1;
    if [ $? = 0 ]; then
        echo $i >> active.services
    else echo $i >> inactive.services

    fi
done

echo "DONE!"

echo "----------------------------------------------"
echo -e "Active(resolvable) host count: `cat active.services |wc -l`
Inactive count: `cat inactive.services |wc -l`"
echo "----------------------------------------------"

echo "##############################################"

echo "This extra part of the script is just to dedup those files into a list."
echo "Each line is a HOST, but the query is on the SIs Collection. So, there is a 1-N relationship here."
echo "----------------------------------------------"
echo -e "DEDUPPED - Active(resolvable) host count: `sort active.services |uniq -u |wc -l`
DEDUPPED - Inactive count: `sort inactive.services |uniq -u |wc -l`"
echo "----------------------------------------------"

rm {active.services,inactive.services,logger.txt}
