#!/bin/bash

# Fail at first error
set -e

PWD=$(pwd)
SOURCES=$PWD/_sources # Where raw repos will be clone to
TARGET=$PWD/_target # Where documentation will build to

# Allows to switch between ssh and https cloning/pulling.
GIT_REMOTE_BASE_URL_SSH=git@github.com:
GIT_REMOTE_BASE_URL_HTTPS=https://github.com/
GIT_REMOTE_BASE_URL=$GIT_REMOTE_BASE_URL_SSH

# Establish external dependencies
declare -a deps=(gitbook ebook-convert)
function depusage() {
		echo "\
To install missing dependencies, run

	$ npm install -g $1

Or, if missing 'ebook-convert' on MacOs...

	$ brew cask install calibre

"
}

# Whitelist projects
declare -a projects=(
	ETCDEVTeam/emerald-cli
	ETCDEVTeam/emerald-js
	#ethereumproject/go-ethereum
	#whilei/go-ethereum # just for dev purposes
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

# Print help/usage in case of invalid use
function usage() {
		echo "Use:"
		echo "--https             : enable https git scheme instead of ssh default (must be arg \$1)"
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

function clone_or_pull_projects() {
	local PROJECT="$1"
	echo "-> Git URL: $GIT_REMOTE_BASE_URL$PROJECT.git"
	echo "-> Source: $SOURCES/$PROJECT"

	# If sources project dir exists, git pull update
	if [ -d "$SOURCES/$PROJECT" ]; then
		if git --work-tree "$SOURCES/$PROJECT" --git-dir "$SOURCES/$PROJECT/.git" pull origin master; then
			echo Success.
		else
			# There was an error... perhaps something like git remote name has changed...
			echo Could not pull from origin master for existing repo "$SOURCES/$PROJECT".

			echo Removing "$SOURCES/$PROJECT"
			rm -rf "$SOURCES/$PROJECT"

			# Make just the owner namespace dir (since we'll clone)
			mkdir -p "$SOURCES/$PROJECT/.."

			cd "$SOURCES/$PROJECT/.." # owner namespace, eg. $SOURCES/ethereumproject/
			if git clone "$GIT_REMOTE_BASE_URL$PROJECT.git"; then
				echo Success.
			else
				echo Used remote url: "$GIT_REMOTE_BASE_URL$PROJECT.git"
				echo Could not clone to "$SOURCES/$PROJECT"
				exit 1
			fi
		fi
	else
		mkdir -p "$SOURCES/$PROJECT/.."
		cd "$SOURCES/$PROJECT/.." # owner namespace, eg. $SOURCES/ethereumproject/
		if git clone "$GIT_REMOTE_BASE_URL$PROJECT.git"; then
			echo Success.
		fi
	fi
}

function build_docs() {
	local PROJECT="$1"
	echo "-> Using Gitbook to bind $PROJECT..."

	# Ensure Gitbook required files exist.
	if [ ! -f "$SOURCES/$PROJECT/book.json" ]; then
		echo "Missing required $SOURCES/$PROJECT/book.json file. Gitbook cannot continue."
		exit 1
	fi
	# TODO: refactor docs dir to script var?
	if [ ! -f "$SOURCES/$PROJECT/docs/README.md" ] && [ ! -f "$SOURCES/$PROJECT/docs/README.adoc" ]; then
		echo "Missing required $SOURCES/$PROJECT/docs/README.(md|adoc) file. Gitbook cannot continue."
		exit 1
	fi

	# Get just the repo name, splitting on '/' from the namespace prefix
	IFS='/' read -ra ARR <<< "$PROJECT"
	local REPONAME="${ARR[1]}"
	echo "-> Repo name: $REPONAME"

	echo "-> Target: $TARGET/html/$REPONAME/"
	gitbook build "$SOURCES/$PROJECT"
	rm -rf "$TARGET/html/$REPONAME/"
	mv "$SOURCES/$PROJECT/_book/" "$TARGET/html/$REPONAME/"

	echo "-> Target: $TARGET/pdf/$REPONAME/"
	rm -rf "$TARGET/pdf/$REPONAME.pdf"
	gitbook pdf "$SOURCES/$PROJECT/." "$TARGET/pdf/$REPONAME.pdf"

	echo "-> Target: $TARGET/epub/$REPONAME/"
	rm -rf "$TARGET/epub/$REPONAME.epub"
	gitbook epub "$SOURCES/$PROJECT/." "$TARGET/epub/$REPONAME.epub"

	git --work-tree "$SOURCES/$PROJECT" --git-dir "$SOURCES/$PROJECT/.git" checkout "$SOURCES/$PROJECT/book.json"
}

function get_and_build() {
	local PROJECT="$1"

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

	clone_or_pull_projects "$PROJECT"
	build_docs "$PROJECT"
}

function deploy() {
	BUCKET="docs.etcdevteam.com"
	gsutil -m rsync -R "$TARGET" "gs://$BUCKET"
	gsutil -m acl ch -u "AllUsers:R" -r "gs://$BUCKET"
	gsutil -m setmeta -h "Cache-Control:public, max-age=900" -r "gs://$BUCKET"
}

# Let the processing begin.

# Create source and target dirs if not exist
[ -d "$SOURCES" ] || mkdir -p "$SOURCES"
[ -d "$TARGET/html" ] || mkdir -p "$TARGET/html"
[ -d "$TARGET/pdf" ] || mkdir -p "$TARGET/pdf"
[ -d "$TARGET/epub" ] || mkdir -p "$TARGET/epub"

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
		echo "-> Git scheme: https"
		GIT_REMOTE_BASE_URL=$GIT_REMOTE_BASE_URL_HTTPS
		shift
		;;
	*)
		echo "-> Git scheme: ssh"
		;;
esac

# Parse options.
while getopts ":b:Bwds" opt; do
  case $opt in
	b)
		echo "-> Building docs for: $OPTARG"
		get_and_build "$OPTARG"
		;;
	B)
		echo "Building all docs: $(printprojects)"
		for p in "${projects[@]}"; do
			echo "Building docs for $p ..."
			get_and_build "$p"
		done
		;;
	w)
		echo "Build main website"
		node webpack.js --minimize
		;;
	d)
		echo "Deploy docs to https://docs.etcdevteam.com"
		deploy
		;;
        s)
		echo "Serve local website. Please open http://localhost:8000 to view generated website"
		cd _target
		python -m SimpleHTTPServer
		;;
	*)  echo "Unknown $1"
		usage
		exit 1
		;;
  esac
done
