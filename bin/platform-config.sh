#!/usr/bin/env bash

. _common.sh


if [ $# -lt 2 ]; then
    echo "Usage: $0 <configfile> <node[1|2|...]>"
    echo "    e.g.: $0 lib/config-2vm.sh node2"
    echo "          $0 lib/config-1vm.sh node1"
    exit 1
fi

configfile="$1"
thisnode="$2"
outfile="$HOME/.modaclouds/env.sh"

if ! [ -e "$configfile" ]; then
    echo "ERROR: $configfile not found" >&2
    exit 1
fi

. "$configfile"

DIR=$( cd "$( dirname "$0" )" && pwd )
template="$DIR/../lib/platform-env.sh.tpl"


function check_config_file() {
    for node in "${!addresses[@]}"; do
        local address=${addresses["$node"]}
        if [ -z "$address" ]; then
            echo -n "ERROR: Address for '$node' is empty. "
            raw_address=$(grep "\[\"$node\"\]" $configfile | sed -e's/.*=\(.*\)$/\1/')
            if [ "${raw_address:0:1}" = '$' ]; then
                echo "Have you exported its value?" >&2
                echo "e.g.: " >&2
                echo "  export ${raw_address:1}=192.168.56.101" >&2
                echo "  $0 $configfile $thisnode" >&2
            fi
            exit 1
        fi
        ping -c 1 "$address" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Warning: $node with address $address could not be pinged"
        fi
        local arr=${node}_instances[@]
        values=$(echo "${!arr}")
        if [ "${#values}" -eq 0 ]; then
            echo "ERROR: Variable ${node}_instances is not defined in $configfile or is empty" >&2
            exit 1
        fi
    done
}

function check_node() {
    if [ -z ${addresses["$1"]} ];
    then
        echo "ERROR: Node '$1' not found" >&2
        exit 1
    fi
}

function get_addr() {
    # 
    # get_addr <instanceid>
    #
    # Get address of an instance id
    #
    for node in "${!addresses[@]}"; do
        local address=${addresses["$node"]}
        local arr=${node}_instances[@]
        for id in "${!arr}"; do
            if [ "$id" = "$1" ]; then
                echo "$address"
                return
            fi
        done
    done
    echo "Warning: $1 not found" >&2
    exit 1
}

function get_public_addr() {
    #
    # get_public_addr <instanceid>
    #
    # Return get_addr if != "0.0.0.0" or get_public_address
    local addr=$(get_addr $1)
    if [ "$addr" = "0.0.0.0" ]; then
        addr=$(get_public_address "$addr")
    fi
    echo "$addr"
}

check_config_file "$configfile"
check_node "$thisnode"

outdir=$(dirname "$outfile")
[ -e "$outdir" ] || mkdir "$outdir"

while IFS='' read -r line
do
    if [[ "$line" =~ ^#.*$ ]]; then
        echo "$line"
    elif [[ "$line" =~ \$\(.*\) ]]; then
        echo "$line"
    elif [[ "$line" =~ .*\$instances.* ]]; then
        arr=${thisnode}_instances[@]
        instances="${!arr}"
        eval echo "$line"
    else
        echo "$line"
    fi
done < "$template" > "$outfile"

outconfigfile="$HOME/.modaclouds/config.sh"
cp "$configfile" "$outconfigfile" 2>/dev/null && echo "Config file has been copied to $outconfigfile" >&2

echo "Output file is $outfile" >&2
