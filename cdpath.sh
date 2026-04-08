#!/bin/bash

# this script will generate a CDPATH vars filled with the most visited directories
# it reads ~/.bash_history, grep, filter, sort, and get the best of 

# should have written that in python, easier to manage array

FILE="${HISTFILE:-$HOME/.bash_history}"

SELF="${BASH_SOURCE[0]##*/}"
NAME="${SELF%.sh}"

OPTS="deEfhstx"
USAGE="Usage: $SELF [$OPTS] [occurence]"
HELP="
  $USAGE

        -d     debug
        -e     bash set -e
        -E     prompt on error
        -f     force
        -h     this help
        -s     simul
        -t     simul
        -x     bash set -x

    diff ~/etc/bashrc.cdpath <(cdpath.sh)
"

function _quit ()
{
    echo -e "$@" >&2
    exit 1
}

function _debug ()
{
    echo -e "$@" >&2
}

unset run setX setE verbose force
verbose=:

while getopts :$OPTS arg
do
    case "$arg" in
        d)    debug=_debug                                          ;;
        e)    setE="set -e"                                         ;;
        E)    trap "read -p 'an error occurred, press ENTER '" ERR  ;;
        f)    force=true                                            ;;
        h)    _quit "$HELP"                                         ;;
        s)    run=echo                                              ;;
        t)    run=echo                                              ;;
        x)    setX="set -x"                                         ;;
        :)    _quit "$SELF: option -$OPTARG needs an argument."     ;;
        *)    _quit "  $USAGE"                                      ;;
    esac
done

shift $(($OPTIND - 1))

$setE
$setX

# default number of occurence to take directory into consideration
occurence="${1:-3}"

[[ "$occurence" == *[![:digit:]]* ]] && _quit "  $SELF: $occurence: Invalid number."

declare -A cdpath

# read bash HISTFILE (== $H) and get the '$dir' part of each "cd $dir" line
while read cd path nonexist
do
    [[ "$cd" == "cd" ]] || continue

    path="${path%/}"
    path="${path/#~/$HOME}"
    # expand $N and other $stuff
    printf -v path "%s" "$path"

    # ignore empty, '..' and '-'
    [[ "$path" == "" || "${path:0:2}" == ".." || "$path" == "-" || -n "$nonexist" ]] && continue 

    (( cdpath[$path] ++ ))

    $debug "grep: cdpath[$path]: ${cdpath[$path]}"

done < $FILE

$debug

for path in "${!cdpath[@]}"
do

    if (( cdpath[$path] < occurence ))
    then
        $debug "filter: $path: ${cdpath[$path]} < occurence, discard"
        unset cdpath["$path"]
        continue
    fi

    # try get absolut path or discard
    if [[ "${path:0:1}" != / && "${path:0:2}" != "~/" ]]
    then
        # prepend current path (this is opend to discussion)
        if [[ -d "$PWD/$path" ]]
        then
            new_path="$PWD/$path"

        # prepend HOME
        elif [[ -d "$HOME/$path" ]]
        then
            new_path="$HOME/$path"
        
        else
            # remove non absolut path
            $debug "filter: $path (${cdpath[$path]}) != absolut path, discard"
            unset cdpath["$path"]
            continue
        fi

        # replace relative path with absolut one
        cdpath["$new_path"]="${cdpath[$path]}"
        unset cdpath["$path"]

        $debug "filter: $path becomes $new_path (${cdpath[$new_path]})"
        path="$new_path"
    fi

    # try to add the parent directory in CDPATH,
    # ex: /usr/local/bin will try to add /usr/local in CDPATH
    # so cd bin or cd bin<tab> will leads to /usr/local/bin
    parent_dir="${path%/*}"

    [[ "$parent_dir" && -d "$parent_dir" ]] || continue

    cdpath["$parent_dir"]="${cdpath[$path]}"

    $debug "filter: $path: adding parent dir $parent_dir (${cdpath[$path]})"

done

$debug

# remove non directories (test -d will follow symlinks)
for path in "${!cdpath[@]}"
do
    # discard if path is not a directory
    if [[ ! -d "$path" ]]
    then
        $debug "filter: $path: (${cdpath[$path]}): no such directory, discard"
        unset cdpath["$path"]
        continue
    fi
done

$debug

declare -a sorted_cdpath

# sort dirs from the most to the less visited
for path1 in "${!cdpath[@]}"
do
    max_path="$path1"
    max_val="${cdpath[$path1]}"
    for path2 in "${!cdpath[@]}"
    do
        (( cdpath[$path2] > max_val )) && max_val="${cdpath[$path2]}" max_path="$path2"
    done
    $debug "sort: $max_val $max_path"
    sorted_cdpath+=("$max_path")
    unset cdpath["$max_path"]
done

$debug

# et voila !
tmp="${sorted_cdpath[*]}"
echo "CDPATH=${tmp// /:}"




