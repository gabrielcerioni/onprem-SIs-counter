#!/bin/bash

# This is a small function to deal with the fact that, even with --quiet, MongoDB output is full of trash on both stdout stderr
filter_mongodb_debug_messages() {
    # Workaround for https://jira.mongodb.org/browse/SERVER-27159
 
    grep -vE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}[+-][0-9]{4}\s+'
}


echo "THE QUERY AND HOST PROCESS STARTS HERE..."

${serviceVariable.SUDO_CMD} docker exec mongoContainer mongo "mongodb://${serviceVariable.admin_user}:${serviceVariable.admin_pass}@${serviceVariable.HOST1}:${serviceVariable.MONGODB_PORT},${serviceVariable.HOST2}:${serviceVariable.MONGODB_PORT},${serviceVariable.HOST3}:${serviceVariable.MONGODB_PORT}/harness?authSource=admin&replicaSet=${serviceVariable.replicaset_name}" --quiet --eval 'db.instance.aggregate([{$lookup: {from: "infrastructureMapping", localField: "infraMappingId", foreignField: "_id", as: "infraMappingStuff"}}, {$unwind: "$infraMappingStuff"},{$lookup: {from: "infrastructureDefinitions", localField: "infraMappingStuff.infrastructureDefinitionId", foreignField: "_id", as: "infraDefinitionsStuff"}}, {$unwind: "$infraDefinitionsStuff"}, {$match:{ $and:[{"isDeleted" : false, infraMappingType: "PHYSICAL_DATA_CENTER_SSH", createdAt: {$gt: 1621382400000}}]}}, {$project: {_id: 0, "instanceInfo.hostName": 1, fakeConcatID: {$concat: [ "$serviceName", "___", "$infraDefinitionsStuff.name", "___", "$instanceInfo.hostName"]}}}, {$group: {_id: "$fakeConcatID", deduppedHostname: {$first: "$instanceInfo.hostName"}}}, {$project: {_id: 0}}]).toArray()' | filter_mongodb_debug_messages > input.json

jq -c '.[].deduppedHostname' input.json | while read i; do
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

rm {active.services,inactive.services,logger.txt}
