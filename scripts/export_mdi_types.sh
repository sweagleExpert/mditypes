#!/usr/bin/env bash
#
# SCRIPT: export_mdi_types.sh
# AUTHOR: dimitris@sweagle.com, filip@sweagle.com
# DATE:   August 2019
# REV:    1.0.Q (Valid are A, B, D, T, Q, and P)
#               (For Alpha, Beta, Dev, Test, QA, and Production)
#
# PLATFORM: Not platform dependent
#
# REQUIREMENTS:	- jq is required for this shell script to work.
#               (see: https://stedolan.github.io/jq/)
#				- tested in bash 4.4 on Mac OS X
#
# PURPOSE:	Export MDI types from a sweagle tenant and store them as properties files in a target directory
#						Directory where properties files will be stored should be provided as input (if none, default is current directory)
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
# set -x   # Uncomment to debug this shell script
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

function get_all_mdi_types() {
	# Get all mdi_types
	#echo "curl $sweagleURL/api/v1/model/mdiType?name=$name --request GET --header 'authorization: bearer $aToken'  --header 'Accept: application/vnd.siren+json'"
	res=$(\
	  curl -sw "%{http_code}" "$sweagleURL/api/v1/model/mdiType" --request GET --header "authorization: bearer $aToken"  --header 'Accept: application/vnd.siren+json' \
		)

	# check curl exit code
	rc=$?; if [ "${rc}" -ne "0" ]; then exit ${rc}; fi;
    # check http return code
	get_httpreturn httpcode res; if [ ${httpcode} -ne "200" ]; then exit 1; fi;

	echo ${res}
}


##########################################################
#               BEGINNING OF MAIN
##########################################################

set -o errexit # exit after first line that fails
set -o nounset # exit when script tries to use undeclared variables

# load sweagle host specific variables like aToken, sweagleURL, ...
source $(dirname "$0")/sweagle.env

# Check input arguments
if [ "$#" -lt "1" ]; then
	echo "*** No target directory provided, will use (.) as output"
	TARGET_DIR="."
else
	if [ -d "$1" ]; then
		TARGET_DIR="$1"
	else
		echo "********** ERROR: ($1) IS NOT A DIRECTORY"
    echo "********** YOU SHOULD PROVIDE TARGET DIRECTORY WHERE YOUR TYPES WILL BE STORED"
    exit 1
	fi
fi

echo "*** Getting all mdi types from SWEAGLE tenant $sweagleURL"
mdi_types=$(get_all_mdi_types)

echo "*** Filter only on valid MDI Types"
mdi_types=$(echo ${mdi_types} | jq '.entities[].properties.version | select(.status=="VALID")')
mdi_types=${mdi_types//"}
{"/"},{"}
#echo "${mdi_types}" > ./toto.json

for row in $(echo "[${mdi_types}]" | jq -r '.[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
	filename="$TARGET_DIR/$(_jq '.name').props"
  echo "name=\"$(_jq '.name')\""  >> $filename
	echo "description=\"$(_jq '.description')\""  >> $filename
	echo "type=$(_jq '.valueType')"  >> $filename
	echo "regex=\"$(_jq '.regex')\""  >> $filename
	echo "isSensitive=$(_jq '.sensitive')"  >> $filename
	echo "isRequired=$(_jq '.required')"  >> $filename
done

exit 0
# End of script
