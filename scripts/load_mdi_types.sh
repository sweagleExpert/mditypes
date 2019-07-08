#!/usr/bin/env bash
#
# SCRIPT: load_mdi_types.sh
# AUTHOR: dimitris@sweagle.com, filip@sweagle.com
# DATE:   July 2019
# REV:    2.0.D (Valid are A, B, D, T, Q, and P)
#               (For Alpha, Beta, Dev, Test, QA, and Production)
#
# PLATFORM: Not platform dependent
#
# REQUIREMENTS:	- jq is required for this shell script to work.
#               (see: https://stedolan.github.io/jq/)
#				- tested in bash 4.4 on Mac OS X
#
# PURPOSE:	Load MDI types stored as properties files, and located in directory provided as input
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
function get_mdi_type() {
	name=${1}

	# Get a mdi_type based on its name
	#echo "curl $sweagleURL/api/v1/model/mdiType?name=$name --request GET --header 'authorization: bearer $aToken'  --header 'Accept: application/vnd.siren+json'"
	res=$(\
	  curl -sw "%{http_code}" "$sweagleURL/api/v1/model/mdiType?name=$name" --request GET --header "authorization: bearer $aToken"  --header 'Accept: application/vnd.siren+json' \
		)

	# check curl exit code
	rc=$?; if [ "${rc}" -ne "0" ]; then exit ${rc}; fi;
    # check http return code
	get_httpreturn httpcode res; if [ ${httpcode} -ne "200" ]; then exit 1; fi;

	id=$(echo ${res} | jq '.entities[].properties.id')
	echo ${id}
}


# arg1: changeset ID
# arg2: name
# arg3: description
# arg4: value_type
# arg5: required
# arg6: sensitive
# arg7: regex
function create_mdi_type() {
	changeset=${1}
	name=${2}
	description=${3:-}
	value_type=${4:-Text}
	required=${5:-false}
	sensitive=${6:-false}
	regex=${7:-}

	# Create a new mdi_type
	res=$(\
		curl -sw "%{http_code}" "$sweagleURL/api/v1/model/mdiType" --request POST --header "authorization: bearer $aToken"  --header 'Accept: application/vnd.siren+json' \
		--data "changeset=${changeset}" \
		--data-urlencode "name=${name}" \
		--data "required=${required}" \
		--data-urlencode "valueType=${value_type}" \
		--data "sensitive=${sensitive}" \
		--data-urlencode "regex=${regex}" \
		--data-urlencode "description=${description}")
	# check curl exit code
	rc=$?; if [ "${rc}" -ne "0" ]; then exit ${rc}; fi;
    # check http return code
	get_httpreturn httpcode res; if [ ${httpcode} -ne "200" ]; then exit 1; fi;

}

# arg1: changeset ID
# arg2: MDI type ID
# arg3: name
# arg4: description
# arg5: value_type
# arg6: required
# arg7: sensitive
# arg8: regex
function update_mdi_type() {
	changeset=${1}
	id=${2}
	name=${3}
	description=${4:-}
	value_type=${5:-Text}
	required=${6:-false}
	sensitive=${7:-false}
	regex=${8:-}

	# Update an existing mdi_type
	res=$(\
		curl -sw "%{http_code}" "$sweagleURL/api/v1/model/mdiType/$id" --request POST --header "authorization: bearer $aToken"  --header 'Accept: application/vnd.siren+json' \
		--data "changeset=${changeset}" \
		--data-urlencode "name=${name}" \
		--data "required=${required}" \
		--data-urlencode "valueType=${value_type}" \
		--data "sensitive=${sensitive}" \
		--data-urlencode "regex=${regex}" \
		--data-urlencode "description=${description}")
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
modelcs=$(create_modelchangeset 'Create MDI Type' "Create a new MDI type at $(date +'%c')")

for file in $1/*.props; do
	echo "Parsing file $file"
	source "$file"
	type_id=$(get_mdi_type "$name")
	if [ -z "$type_id" ]; then
		echo "*** No existing MDI type $name, create it"
		create_mdi_type $modelcs "$name" "$description" $type $isRequired $isSensitive ${regex}
	else
		echo "*** MDI type $name already exits with id $type_id, update it"
		update_mdi_type $modelcs "$type_id" "$name" "$description" $type $isRequired $isSensitive ${regex}
	fi
done

# approve
approve_model_changeset ${modelcs}
rc=$?; if [[ "${rc}" -ne 0 ]]; then echo "Model changeset approval failed"; exit ${rc}; fi

exit 0

# End of script
