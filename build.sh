#!/bin/bash

ME=$(pwd)
SOURCES=$ME/_sources
TARGET=$ME/_target

[ -d $SOURCES ] || mkdir -p $SOURCES
[ -d "$TARGET/html" ] || mkdir -p "$TARGET/html"
[ -d "$TARGET/pdf" ] || mkdir -p "$TARGET/pdf"
[ -d "$TARGET/epub" ] || mkdir -p "$TARGET/epub"

set -e

function get_sources() {
    PROJECT=$1
    GIT=git@github.com:ETCDEVTeam/$PROJECT.git
    echo "Get sources $GIT at $SOURCES"

    cd $SOURCES
    mkdir -p $TARGET/$PROJECT

    if [ -d "./$PROJECT" ]; then
        cd $PROJECT
        git pull origin master
    else
        git clone $GIT
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
}

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
	usage
	exit 1
fi

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

