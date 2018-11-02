#!/bin/bash
# 10-17-18
# Nessus Manager Scan Export Script

# 1. Gets all Scan ID's in an array
# 2. Passes each Scan ID into another loop, and sort history id by largest value (most recent scan results)
# 3. Passes that History ID value into an export API call
# 4. Asks for file status of each scan report, if the status is ready, proceed, otherwise, wait until export is done.


s1="ready"
s2="loading"
s3="null"
accessKey=""
secretKey=""

#checks for jq, install if not installed.
echo "Checking for dependency jq, installing if not installed."
sleep 1s
rpm -qa | grep -qw jq || yum install -y jq
sleep 2s
echo "Starting report export"
sleep 1s

arr=($(curl -k -s -H "X-ApiKeys: accessKey=$accessKey; secretKey=$secretKey" https://nessusIP:443/scans | jq -r '.scans[].id'))
for i in "${arr[@]}"; do
	# gets most recent history ID to export
	arr2=($(curl -k -s -N -H "X-ApiKeys: accessKey=$accessKey; secretKey=$secretKey" https://nessusIP:443/scans/{"$i"} | jq -r '.history[].history_id'))
	# Sort History ID by largest value
	max=${arr2[0]}
	for x in "${arr2[@]}" ; do
		((x > max)) && max="$x"
	done
	echo "Scan ID:" "$i" "starting."
	#Exports report in nessus format and gets file id
	file_id=$(curl -k -s -N -H "X-ApiKeys: accessKey=$accessKey; secretKey=$secretKey" -H 'Content-Type: application/json' -d '{"format": "nessus"}' https://nessusIP:443/scans/{"$i"}/export?history_id={"$max"} | jq -r '.file')
	echo "Most Recent History ID:""$max" "has File ID:" "$file_id"
	
	exportFunc() {
	#asks for file status of each scan export, if status eq "ready" then it proceeds, otherwise, it waits
	export_status=$(curl -k -s -N -H "X-ApiKeys: accessKey=$accessKey; secretKey=$secretKey" -H 'Content-Type: application/json' https://nessusIP:443/scans/{"$i"}/export/{"$file_id"}/status | jq -r '.status')
	echo "Export Status for Scan ID ""$i" "is:" "$export_status"
		if [ "$export_status" == "$s1" ]; then
			curl -k -s -N -H "X-ApiKeys: accessKey=$accessKey; secretKey=$secretKey" -H 'Content-Type: application/json' https://nessusIP/scans/{"$i"}/export/{"$file_id"}/download -o "/data/tenable/report_#1.nessus"
			echo "Exporting..."
			echo ""
		elif [ "$export_status" == "$s2" ]; then
			echo "Waiting for report to render on Nessus Manager... Retrying in 10s"
			sleep 10s
			echo "Trying again..." && exportFunc
		elif [ "$export_status" == "$s3" ]; then
			echo "API returned null, no scan data available, or scan is currently active"
			echo ""
		else
			echo "Export failed...."
			echo ""

		fi
	}	
exportFunc
done

