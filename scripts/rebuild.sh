#!/bin/bash

# This script is to be executed from inside the VM to rebuild XNAT.
# Gradle will be executed and dependencies downloaded in the VM.

OWD=${PWD}

# Exit with error status
die() {
    echo >&2 "$@"
    exit -1
}

[[ -e vars.sh  ]] || die "vars.sh file is required for rebuild script"

source vars.sh

echo
echo Stopping Tomcat...
sudo service tomcat7 stop

echo
echo Deleting web app and rebuilding XNAT...

sudo rm -Rf /var/lib/tomcat7/webapps/ROOT*

if [[ -d ${DATA_ROOT}/src/${XNAT_DIR}  ]]; then

    cd ${DATA_ROOT}/src/${XNAT_DIR}

    REFRESH=N

    echo
    read -p "Would you like to refresh dependencies? This takes longer, but may help resolve build issues. [y/N] " REFRESH

    if [[ $REFRESH =~ [Yy] ]]; then
        echo
        echo Executing Gradle build with refresh...
        ./gradlew clean war --refresh-dependencies
    else
        echo
        echo Executing Gradle build...
        ./gradlew clean war # deployToTomcat # we'll manually copy the war file so we have it if we want to just redeploy
    fi

    echo
    cp -v ${DATA_ROOT}/src/${XNAT_DIR}/build/libs/ROOT.war /var/lib/tomcat7/webapps

    cd $OWD

fi

# Reset database?
DESTROY=N
echo
read -p "Would you like to reset the database? ALL DATABASE DATA IN THIS VM WILL BE DESTROYED. [y/N] " DESTROY

if [[ $DESTROY =~ [Yy] ]]; then
    echo
    echo "Dropping '${PROJECT}' database."
    dropdb -U $VM_USER $PROJECT
    echo
    echo "Creating new '${PROJECT}' database."
    createdb -U $VM_USER $PROJECT
fi

echo
echo Restarting Tomcat...
sudo service tomcat7 start || die "Tomcat startup failed."

echo
echo Rebuild complete.
echo
