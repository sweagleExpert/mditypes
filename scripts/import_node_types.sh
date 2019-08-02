#!/usr/bin/env bash
#
# SCRIPT: load_node_types.sh
# AUTHOR: dimitris@sweagle.com, filip@sweagle.com
# DATE:   July 2019
# REV:    1.0.D (Valid are A, B, D, T, Q, and P)
#               (For Alpha, Beta, Dev, Test, QA, and Production)
#
# PLATFORM: Not platform dependent
#
# REQUIREMENTS:	- jq is required for this shell script to work.
#               (see: https://stedolan.github.io/jq/)
#				- tested in bash 4.4 on Mac OS X
#
# PURPOSE:	Load NODES types stored as json files, and located in directory provided as input
#
# REV LIST:
#        DATE: DATE_of_REVISION
#        BY:   AUTHOR_of_MODIFICATION
#        MODIFICATION: Describe what was modified, new features, etc--
#
#
# set -n   # Uncomment to check script syntax, without execution.
#          # NOTE: Do not forget to put the # comment back in or
#          #       the shell script will never execute!
#set -x   # Uncomment to debug this shell script
#
##########################################################
#               FILES AND VARIABLES
##########################################################

# command line arguments
this_script=$(basename $0)
host=${1:-}

##########################################################
#                    FUNCTIONS
##########################################################

# arg1: http result (incl. http code)
# arg2: httpcode (by reference)
function get_httpreturn() {
	local -n __http=${1}
	local -n __res=${2}

	__http="${__res:${#__res}-3}"
    if [ ${#__res} -eq 3 ]; then
      __res=""
    else
      __res="${__res:0:${#__res}-3}"
    fi
}

# arg1: title
# arg2: description
function create_modelchangeset() {
	title=${1}
	description=${2}

	# Create and open a new changeset
	res=$(\
		curl -sw "%{http_code}" "$sweagleURL/api/v1/model/changeset" --request POST --header "authorization: bearer $aToken"  --header 'Accept: application/vnd.siren+json' \
		--data-urlencode "title=${title}" \
		--data-urlencode "description=${description}")
	# check exit code
	rc=$?; if [ "${rc}" -ne "0" ]; then exit ${rc}; fi;
    # check http return code
	get_httpreturn httpcode res; if [ ${httpcode} -ne "200" ]; then exit 1; fi;

  cs=$(echo ${res} | jq '.properties.changeset.id')
	echo ${cs}
}

# arg1: name
function get_node_type() {
	name=${1}

	# Get a mdi_type based on its name
	#echo "curl $sweagleURL/api/v1/model/mdiType?name=$name --request GET --header 'authorization: bearer $aToken'  --header 'Accept: application/vnd.siren+json'"
	res=$(\
	  curl -sw "%{http_code}" "$sweagleURL/api/v1/model/type?name=$name" --request GET --header "authorization: bearer $aToken"  --header 'Accept: application/vnd.siren+json' \
		)

	# check curl exit code
	rc=$?; if [ "${rc}" -ne "0" ]; then exit ${rc}; fi;
  # check http return code
	get_httpreturn httpcode res; if [ ${httpcode} -ne "200" ]; then exit 1; fi;

	id=$(echo ${res} | jq '.entities[0].properties.id')
	echo ${id}
}

# arg1: type id
# arg2: name
function get_type_attribute() {
	id=${1}
	name=${2:-}

	# Get a type attributes based on type id
	res=$(\
	  curl -sw "%{http_code}" "$sweagleURL/api/v1/model/attribute?type=$id" --request GET --header "authorization: bearer $aToken"  --header 'Accept: application/vnd.siren+json' \
		)

	# check curl exit code
	rc=$?; if [ "${rc}" -ne "0" ]; then exit ${rc}; fi;
  # check http return code
	get_httpreturn httpcode res; if [ ${httpcode} -ne "200" ]; then exit 1; fi;

	if [ -n "${name}" ]; then
		# Get attribute ID based on its name
		attr_id=$(echo ${res} | jq --arg attr_name ${name} '.entities[].properties | select(.identifierKey|index($attr_name)) | .id')
	else
		# Return list of existing attributes names
		attr_id=$(echo ${res} | jq '.entities[].properties.identifierKey')
	fi
	echo ${attr_id}
}

# arg1: changeset ID
# arg2: type ID
# arg3: name
# arg4: description
# arg5: valueType
# arg6: required
# arg7: sensitive
# arg8: regex
# arg9: dateFormat
# arg10: defaultValue
# arg11: referenceTypeName
function create_type_attribute() {
	changeset=${1}
	type_id=${2}
	name=${3}
	description=${4:-}
	valueType=${5:-Text}
	required=${6:-false}
	sensitive=${7:-false}
	regex=${8:-}
	listOfValues=${9:-}
	dateFormat=${10:-}
	defaultValue=${11:-}
	referenceTypeName=${12:-}

  # Calculate URL depending on referenceType, because both referenceType or valueType must not be present at same time
	if [ -n "${referenceTypeName}" ]; then
		# if there is a refence name, then find referenced type
		referenceTypeId=$(get_node_type "$referenceTypeName")
		createURL="$sweagleURL/api/v1/model/attribute?referenceType=${referenceTypeId}"
	else
		createURL="$sweagleURL/api/v1/model/attribute?valueType=${valueType}"
	fi

	# Create a new type_attribute
	res=$(\
		curl -sw "%{http_code}" "$createURL" --request POST --header "authorization: bearer $aToken"  --header 'Accept: application/vnd.siren+json' \
		--data "changeset=${changeset}" \
		--data "type=${type_id}" \
		--data-urlencode "name=${name}" \
		--data-urlencode "description=${description}" \
		--data "required=${required}" \
		--data "sensitive=${sensitive}" \
		--data-urlencode "regex=${regex}" \
		--data-urlencode "listOfValues=${listOfValues}" \
		--data-urlencode "dateFormat=${dateFormat}" \
		--data-urlencode "defaultValue=${defaultValue}")

	# check curl exit code
	rc=$?; if [ "${rc}" -ne "0" ]; then exit ${rc}; fi;
	# check http return code, it's ok if 200 (OK) or 201 (created)
	get_httpreturn httpcode res; if [[ "${httpcode}" != 20* ]]; then exit 1; fi;
}

# arg1: changeset ID
# arg2: name
function create_node_type() {
	changeset=${1}
	name=${2}

	# Manage specific integer and date args to avoid conversion error if empty string
	args=""
	if [ -n "${endOfLife}" ]; then
		args="?endOfLife=$endOfLife"
	fi
	if [ -n "${numberOfChildNodes}" ]; then
		if [ -z "$args" ]; then
			args="?numberOfChildNodes=$numberOfChildNodes"
		else
			args="$args&numberOfChildNodes=$numberOfChildNodes"
		fi
	fi
	if [ -n "${numberOfIncludes}" ]; then
		if [ -z "$args" ]; then
			args="?numberOfIncludes=$numberOfIncludes"
		else
			args="$args&numberOfIncludes=$numberOfIncludes"
		fi
	fi
	createURL="$sweagleURL/api/v1/model/type$args"

	# Create a new node_type
	res=$(\
		curl -sw "%{http_code}" "$createURL" --request POST --header "authorization: bearer $aToken"  --header 'Accept: application/vnd.siren+json' \
		--data "changeset=${changeset}" \
		--data-urlencode "name=${name}" \
		--data-urlencode "description=${description}" \
		--data "inheritFromParent=${inheritFromParent}" \
		--data "internal=${internal}" \
		--data "isMetadataset=${isMetadataset}" )

	# check curl exit code
	rc=$?; if [ "${rc}" -ne "0" ]; then exit ${rc}; fi;
  # check http return code, it's ok if 200 (OK) or 201 (created)
	get_httpreturn httpcode res; if [[ "${httpcode}" != 20* ]]; then exit 1; fi;

	# Get the node ID created
	id=$(echo ${res} | jq '.properties.id')
	echo ${id}
}


# arg1: changeset ID
# arg2: type ID
# arg3: name
function delete_type_attribute() {
	changeset=${1}
	type_id=${2}
	name=${3}

	# get attribute ID from name
	attr_id=$(get_type_attribute $type_id "${name}")

	# delete attribute
	deleteURL="$sweagleURL/api/v1/model/attribute/${attr_id}?changeset=${changeset}&type=${type_id}"
	res=$(\
		curl -sw "%{http_code}" "$deleteURL" --request DELETE --header "authorization: bearer $aToken"  --header 'Accept: application/vnd.siren+json')

	# check curl exit code
	rc=$?; if [ "${rc}" -ne "0" ]; then exit ${rc}; fi;
	# check http return code, it's ok if 200 (OK) or 201 (created)
	get_httpreturn httpcode res; if [ ${httpcode} -ne 200 ]; then exit 1; fi;
}


# arg1: changeset ID
# arg2: type ID
# arg3: attribute ID
# arg4: name
# arg5: description
# arg6: valueType
# arg7: required
# arg8: sensitive
# arg9: regex
# arg10: dateFormat
# arg11: defaultValue
# arg12: referenceTypeName
function update_type_attribute() {
	changeset=${1}
	type_id=${2}
	attr_id=${3}
	name=${4}
	description=${5:-}
	valueType=${6:-Text}
	required=${7:-false}
	sensitive=${8:-false}
	regex=${9:-}
	listOfValues=${10:-}
	dateFormat=${11:-}
	defaultValue=${12:-}
	referenceTypeName=${13:-}

  # Calculate URL depending on referenceType, because both referenceType or valueType must not be present at same time
	if [ -n "${referenceTypeName}" ]; then
		# if there is a refence name, then find referenced type
		referenceTypeId=$(get_node_type "$referenceTypeName")
		updateURL="$sweagleURL/api/v1/model/attribute/$attr_id?referenceType=${referenceTypeId}"
	else
		updateURL="$sweagleURL/api/v1/model/attribute/$attr_id?valueType=${valueType}"
	fi

	# update a type_attribute
	res=$(\
		curl -sw "%{http_code}" "$updateURL" --request POST --header "authorization: bearer $aToken"  --header 'Accept: application/vnd.siren+json' \
		--data "changeset=${changeset}" \
		--data "type=${type_id}" \
		--data-urlencode "name=${name}" \
		--data-urlencode "description=${description}" \
		--data "required=${required}" \
		--data "sensitive=${sensitive}" \
		--data-urlencode "regex=${regex}" \
		--data-urlencode "listOfValues=${listOfValues}" \
		--data-urlencode "dateFormat=${dateFormat}" \
		--data-urlencode "defaultValue=${defaultValue}")

	# check curl exit code
	rc=$?; if [ "${rc}" -ne "0" ]; then exit ${rc}; fi;
  # check http return code
	get_httpreturn httpcode res; if [ ${httpcode} -ne "200" ]; then exit 1; fi;
}

# arg1: changeset ID
# arg2: NODE type ID
# arg3: name
# arg4: description
# arg5: inheritFromParent
# arg6: internal
# arg7: isMetadataset
# arg8: endOfLife
# arg9: numberOfChildNodes
# arg10: numberOfIncludes
function update_node_type() {
	changeset=${1}
	id=${2}
	name=${3}
	description=${4:-}
	inheritFromParent=${5:-false}
	internal=${6:-false}
	isMetadataset=${7:-false}
	endOfLife=${8:-}
	numberOfChildNodes=${9:-}
	numberOfIncludes=${10:-}

	# Manage specific integer and date args to avoid conversion error if empty string
	args=""
	if [ -n "${endOfLife}" ]; then
		args="?endOfLife=$endOfLife"
	fi
	if [ -n "${numberOfChildNodes}" ]; then
		if [ -z "$args" ]; then
			args="?numberOfChildNodes=$numberOfChildNodes"
		else
			args="$args&numberOfChildNodes=$numberOfChildNodes"
		fi
	fi
	if [ -n "${numberOfIncludes}" ]; then
		if [ -z "$args" ]; then
			args="?numberOfIncludes=$numberOfIncludes"
		else
			args="$args&numberOfIncludes=$numberOfIncludes"
		fi
	fi
	updateURL="$sweagleURL/api/v1/model/type/$id$args"

# Update an existing node_type
	res=$(\
		curl -sw "%{http_code}" "$updateURL" --request POST --header "authorization: bearer $aToken"  --header 'Accept: application/vnd.siren+json' \
		--data "changeset=${changeset}" \
		--data-urlencode "name=${name}" \
		--data-urlencode "description=${description}" \
		--data "inheritFromParent=${inheritFromParent}" \
		--data "internal=${internal}" \
		--data "isMetadataset=${isMetadataset}" )
	# check curl exit code
	rc=$?; if [ "${rc}" -ne "0" ]; then exit ${rc}; fi;
  # check http return code
	get_httpreturn httpcode res; if [ ${httpcode} -ne "200" ]; then exit 1; fi;

}

# arg1: changeset ID
function approve_model_changeset() {
	changeset=${1}
	# Create and open a new changeset
	res=$(curl -sw "%{http_code}" "$sweagleURL/api/v1/model/changeset/${changeset}/approve" --request POST --header "authorization: bearer $aToken"  --header 'Accept: application/vnd.siren+json')
	# check curl exit code
	rc=$?; if [ "${rc}" -ne "0" ]; then exit ${rc}; fi;
    # check http return code
	get_httpreturn httpcode res; if [ ${httpcode} -eq "200" ]; then return 0; else return 1; fi;
}

# arg1: json string to parse
function parse_json_attribute() {
	json=$(echo ${1} | jq --arg attr_name ${2} '.[] | select(.name|index($attr_name))')

	name=$(echo ${2})
	description=$(echo ${json} | jq -r '.description // empty')
	defaultValue=$(echo ${json} | jq -r '.defaultValue // empty')
	required=$(echo ${json} | jq -r '.required // empty')
	sensitive=$(echo ${json} | jq -r '.sensitive // empty')
	referenceTypeName=$(echo ${json} | jq -r '.referenceTypeName // empty')
	valueType=$(echo ${json} | jq -r '.valueType // empty')
	regex=$(echo ${json} | jq -r '.regex // empty')
	listOfValues=$(echo ${json} | jq -r '.listOfValues // empty')
	dateFormat=$(echo ${json} | jq -r '.dateFormat // empty')
}

# arg1: json file to parse
function parse_json_node_type() {
	json=$(cat ${1})

	name=$(echo ${json} | jq -r '.name')
	description=$(echo ${json} | jq -r '.description // empty')
	endOfLife=$(echo ${json} | jq -r '.endOfLife // empty')
	inheritFromParent=$(echo ${json} | jq -r '.inheritFromParent // empty')
	internal=$(echo ${json} | jq -r '.internal // empty')
	isMetadataset=$(echo ${json} | jq -r '.isMetadataset  // empty')
	numberOfChildNodes=$(echo ${json} | jq -r '.numberOfChildNodes  // empty')
	numberOfIncludes=$(echo ${json} | jq -r '.numberOfIncludes // empty')
	attributes=$(echo ${json} | jq -c '.attributes  // empty')
}


##########################################################
#               BEGINNING OF MAIN
##########################################################

set -o errexit # exit after first line that fails
set -o nounset # exit when script tries to use undeclared variables

# load sweagle host specific variables like aToken, sweagleURL, ...
source $(dirname "$0")/sweagle.env

if [ "$#" -lt "1" ]; then
    echo "********** ERROR: NOT ENOUGH ARGUMENTS SUPPLIED"
    echo "********** YOU SHOULD PROVIDE 1- DIRECTORY WHERE YOUR TYPES ARE STORED"
    exit 1
fi

# create a new model changeset
modelcs=$(create_modelchangeset 'Create NODE Types' "Create new NODE types at $(date +'%c')")

for file in $1/*.json; do
	echo "***************************************************************"
	echo "*** Parsing file $file"
	parse_json_node_type "$file"
	type_id=$(get_node_type "$name")
	if [ -z "$type_id" ] || [ "$type_id" == "null" ]; then
		echo "*** No existing NODE type $name, create it"
		type_id=$(create_node_type $modelcs "$name")
		echo "Node type created with ID $type_id, creating attributes"

		while IFS=$'\n' read -r attr; do
				attr=$(echo "${attr//[/}")
				attr=$(echo "${attr//]/}")
				#IFS=',' read -a attribute <<< "$attr"
				attr=$(echo "${attr//,/ }")
				eval "attribute=($attr)"
				#parse_json_attribute ${attribute}
				#create_type_attribute $modelcs $type_id $name $description $valueType $required $sensitive $regex $dateFormat $defaultValue $referenceTypeName
				create_type_attribute $modelcs $type_id "${attribute[0]}" "${attribute[1]}" "${attribute[2]}" "${attribute[3]}" "${attribute[4]}" "${attribute[5]}" "${attribute[6]}" "${attribute[7]}" "${attribute[8]}" "${attribute[9]}"
				echo "* Attribute (${attribute[0]}) created"
		done< <(jq -c -r '.attributes[] | [.name,.description,.valueType,.required,.sensitive,.regex,.listOfValues,.dateFormat,.defaultValue,.referenceTypeName]' < $file)
# PROBLEM OF THE CODE BELOW : RECORDS ARE SPLITTED BECAUSE OF SPACES IN DESCRIPTION FIELD
#  	for row in $(echo "$attributes" | jq -c -r '.[] | [.name,.description,.defaultValue]'); do
#			echo "row=${row}"
#			parse_json_attribute ${row}
			#create_type_attribute $modelcs $type_id $name $description $valueType $required $sensitive $regex $dateFormat $defaultValue $referenceTypeName
#		done

	else
		echo "*** NODE type $name already exits with id ($type_id), update it"
		update_node_type $modelcs "$type_id" "$name" "$description" "$inheritFromParent" "$internal" "$isMetadataset" "$endOfLife" "$numberOfChildNodes" "$numberOfIncludes"

		# Check what should be made with attributes
		# Compare new and old lists of attributes
		old_attr_list=$(get_type_attribute $type_id)
		new_attr_list=$(echo ${attributes} | jq '.[].name')
		echo $old_attr_list | sed 's/ /\n/g'| sort > ./old.tmp
		echo $new_attr_list | sed 's/ /\n/g'| sort > ./new.tmp

		eval "attr_arr=($(comm -13 ./new.tmp ./old.tmp))"
		for i in "${attr_arr[@]}"
		do
		   echo "* Delete attribute ($i)"
			 delete_type_attribute $modelcs $type_id "$i"
		done

		eval "attr_arr=($(comm -23 ./new.tmp ./old.tmp))"
		for i in "${attr_arr[@]}"
		do
		   echo "* Create attribute ($i)"
			 parse_json_attribute "${attributes}" "$i"
			 create_type_attribute $modelcs $type_id "$name" "$description" "$valueType" "$required" "$sensitive" "$regex" "$listOfValues" "$dateFormat" "$defaultValue" "$referenceTypeName"
		done

		eval "attr_arr=($(comm -12 ./new.tmp ./old.tmp))"
		for i in "${attr_arr[@]}"
		do
		   echo "* Update attribute ($i)"
			 attr_id=$(get_type_attribute $type_id "$i")
			 parse_json_attribute "${attributes}" "$i"
			 update_type_attribute $modelcs $type_id $attr_id "$name" "$description" "$valueType" "$required" "$sensitive" "$regex" "$listOfValues" "$dateFormat" "$defaultValue" "$referenceTypeName"
		done

		rm -f ./new.tmp
		rm -f ./old.tmp
	fi
done

# approve
approve_model_changeset ${modelcs}
rc=$?; if [[ "${rc}" -ne 0 ]]; then echo "Model changeset approval failed"; exit ${rc}; fi

exit 0

# End of script
