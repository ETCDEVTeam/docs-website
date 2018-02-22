#!/bin/bash

PWD=$(pwd)
SOURCES=$PWD/_sources
TARGET=$PWD/_target

# Allows to switch between ssh and https cloning/pulling.
GIT_REMOTE_BASE_URL_SSH=git@github.com:
GIT_REMOTE_BASE_URL_HTTPS=https://github.com/
GIT_REMOTE_BASE_URL=$GIT_REMOTE_BASE_URL_SSH

# Establish external dependencies
declare -a deps=(gitbook ebook-convert)
declare -a projects=(
	ETCDEVTeam/emerald-cli 
	ethereumproject/go-ethereum 
	whilei/go-ethereum
)

function printprojects() {
	local out="
"
	for p in "${projects[@]}"; do
		out="$out
	$p"
	done
	echo "$out"
}

[ -d "$SOURCES" ] || mkdir -p "$SOURCES"
[ -d "$TARGET/html" ] || mkdir -p "$TARGET/html"
[ -d "$TARGET/pdf" ] || mkdir -p "$TARGET/pdf"
[ -d "$TARGET/epub" ] || mkdir -p "$TARGET/epub"

set -e

function get_projects() {
    PROJECT=$1
    echo "Get projects $GIT_REMOTE_BASE_URL/$PROJECT.git at $SOURCES"

    cd "$SOURCES"
	if [ ! -d "$TARGET/$PROJECT" ]; then
    	mkdir -p "$TARGET/$PROJECT"
	fi

    if [ -d "./$PROJECT" ]; then
        cd "$PROJECT"
        if git pull origin master; then
			echo Success.
		else
			echo Could not pull from origin master for existing repo.
			cd "$SOURCES"
			echo pwd "$(pwd)"
			echo removing "./$PROJECT"
			rm -rf "./$PROJECT"
			mkdir -p "./$PROJECT/.."

			# TODO: refactor me DRY
			if git clone "$GIT_REMOTE_BASE_URL""$PROJECT.git"; then
				echo Success.
			fi
		fi
    else
        if git clone "$GIT_REMOTE_BASE_URL""$PROJECT.git"; then
			echo Success.
		fi
    fi
}

function build_docs() {
    PROJECT=$1
	mkdir -p "$SOURCES/$PROJECT"
    cd "$SOURCES/$PROJECT"

    gitbook build
    rm -rf "$TARGET/html/$PROJECT/"
    mv _book/ "$TARGET/html/$PROJECT/"

    rm -rf "$TARGET/pdf/$PROJECT.pdf"
    gitbook pdf ./ "$TARGET/pdf/$PROJECT.pdf"

    rm -rf "$TARGET/epub/$PROJECT.epub"
    gitbook epub ./ "$TARGET/epub/$PROJECT.epub"

    git checkout book.json
}

function build() {
    PROJECT=$1

	# Ensure project is whitelisted.
	local match=0
	for s in "${projects[@]}"; do
		if [ "$s" == "$PROJECT" ]; then
			match=1
		fi
	done
	if [ $match -eq 0 ]; then
		echo "Unknown source $PROJECT"
		echo "Known projects are: $(printprojects)"
		exit 1
	fi

    get_projects "$PROJECT"
    build_docs "$PROJECT"
}

function deploy() {
    BUCKET="docs.etcdevteam.com"
    gsutil -m rsync -R "$TARGET" "gs://$BUCKET"
    gsutil -m acl ch -u "AllUsers:R" -r "gs://$BUCKET"
    gsutil -m setmeta -h "Cache-Control:public, max-age=900" -r "gs://$BUCKET"
}

function usage() {
        echo "Use:"
		echo "--https             : enable https git scheme instead of ssh default"
		echo " -B                 : build docs for all available projects

	Available projects are: $(printprojects)

"
        echo " -b <project>       : build docs for a single project or multiple

	To build for specific single or multiple projects, use '-b project1 -b project2'
"
        echo " -w                 : build website"
        echo " -d                 : deploy"

		echo "\

Examples:

	$ ./build.sh --https -b emerald-cli
	$ ./build.sh -b emerald-cli -b go-ethereum

"
}

function depusage() {
		echo "\
To install missing dependencies, run

	$ npm install -g $1

Or, if missing 'ebook-convert' on MacOs...

	$ brew cask install calibre

"
}

# Check for minimum arguments existing.
if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
	usage
	exit 1
fi

# Ensure dependencies exist.
for dep in "${deps[@]}"; do
	hash "$dep" 2>/dev/null || { echo >&2 "I require $dep but it's not installed.  Aborting."; depusage "$dep"; exit 1; }
done

# Parse git scheme.
case "$1" in
	--https)
		echo "Using https git scheme"
		GIT_REMOTE_BASE_URL=$GIT_REMOTE_BASE_URL_HTTPS
		shift
		;;
esac

while getopts ":b:Bwd" opt; do
  case $opt in
    b)
		echo "\
-> Building docs: $OPTARG"
		build "$OPTARG"
		;;
	B)
		echo "Building all docs: $(printprojects)"
		for p in "${projects[@]}"; do
			echo "Building $p ..."
			build "$p"
		done
		;;
	w)
        echo "Build main website"
        node webpack.js --no-watch --minimize
        ;;
    d)
        echo "Deploy docs to https://docs.etcdevteam.com"
        deploy
        ;;
    *)  echo "Unknown $1"
		usage
        exit 1
        ;;
  esac
#   shift
done

