#!/bin/bash

ME=$(pwd)
SOURCES=$ME/_sources
TARGET=$ME/_target
# Allows to switch between ssh and https cloning/pulling.
GIT_REMOTE_BASE_URL_SSH=git@github.com:
GIT_REMOTE_BASE_URL_HTTPS=https://github.com/
GIT_REMOTE_BASE_URL=$GIT_REMOTE_BASE_URL_SSH

# Establish external dependencies
declare -a deps=(gitbook ebook-convert)

[ -d $SOURCES ] || mkdir -p $SOURCES
[ -d "$TARGET/html" ] || mkdir -p "$TARGET/html"
[ -d "$TARGET/pdf" ] || mkdir -p "$TARGET/pdf"
[ -d "$TARGET/epub" ] || mkdir -p "$TARGET/epub"

set -e

function get_sources() {
    PROJECT=$1
    echo "Get sources $GIT_REMOTE_BASE_URL""ETCDEVTeam/$PROJECT.git at $SOURCES"

    cd $SOURCES
    mkdir -p $TARGET/$PROJECT

    if [ -d "./$PROJECT" ]; then
        cd $PROJECT
        git pull origin master
    else
        if git clone "$GIT_REMOTE_BASE_URL"ETCDEVTeam/"$PROJECT.git"; then
			echo Got it.
		else
			echo "Failed to clone from ETCDEVTEAM, trying ethereumproject/..."
			git clone "$GIT_REMOTE_BASE_URL"ethereumproject/"$PROJECT.git"
		fi
    fi
}

function build_docs() {
    PROJECT=$1
    cd $SOURCES/$PROJECT

    gitbook build
    rm -rf $TARGET/html/$PROJECT/
    mv _book/ $TARGET/html/$PROJECT/

    rm -rf $TARGET/pdf/$PROJECT.pdf
    gitbook pdf ./ $TARGET/pdf/$PROJECT.pdf

    rm -rf $TARGET/epub/$PROJECT.epub
    gitbook epub ./ $TARGET/epub/$PROJECT.epub

    git checkout book.json
}

function build() {
    PROJECT=$1
    get_sources 'emerald-cli'
    build_docs 'emerald-cli'
}

function deploy() {
    BUCKET="docs.etcdevteam.com"
    gsutil -m rsync -R $TARGET "gs://$BUCKET"
    gsutil -m acl ch -u "AllUsers:R" -r "gs://$BUCKET"
    gsutil -m setmeta -h "Cache-Control:public, max-age=900" -r "gs://$BUCKET"
}

function usage() {
        echo "Use:"
        echo " -b - build docs"
        echo " -w - build website"
        echo " -d - deploy"

		echo "\
	An example or two:

		$ ./build.sh --https -b

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

while getopts "bwd" opt; do
  case $opt in
    b)
        echo "Build docs"
        build 'emerald-cli'
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
  shift
done

