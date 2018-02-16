#!/bin/bash

echo "###############################################################################"
echo "#  MAKE SURE YOU ARE LOGGED IN:                                               #"
echo "#  $ oc login http://console.your.openshift.com                               #"
echo "###############################################################################"

function usage() {
    echo
    echo "Usage:"
    echo " $0 [command] [options]"
    echo " $0 --help"
    echo
    echo "Example:"
    echo " $0 deploy --project-suffix mydemo"
    echo
    echo "COMMANDS:"
    echo "   deploy                   Set up the demo projects and deploy demo apps"
    echo "   delete                   Clean up and remove demo projects and objects"
    echo "   idle                     Make all demo servies idle"
    echo "   unidle                   Make all demo servies unidle"
    echo
    echo "OPTIONS:"
    echo "   --user [username]         The admin user for the demo projects. mandatory if logged in as system:admin"
    echo "   --project-suffix [suffix] Suffix to be added to demo project names e.g. ci-SUFFIX. If empty, user will be used as suffix"
    echo "   --ephemeral               Deploy demo without persistent storage"
    echo "   --use-sonar               Use SonarQube for static code analysis instead of CheckStyle,FindBug,etc"
    echo "   --oc-options              oc client options to pass to all oc commands e.g. --server https://my.openshift.com"
    echo "   --domain-name             Domain name for target Openshift install... For Eg: For homework lab its apps.2245.openshift.opentlc.com"
    echo
}

ARG_USERNAME=
ARG_PROJECT_SUFFIX=
ARG_COMMAND=
ARG_EPHEMERAL=false
ARG_OC_OPS=
ARG_WITH_SONAR=false
ARG_DOMAIN_NAME=apps.2245.openshift.opentlc.com

while :; do
    case $1 in
        deploy)
            ARG_COMMAND=deploy
            ;;
        delete)
            ARG_COMMAND=delete
            ;;
        idle)
            ARG_COMMAND=idle
            ;;
        unidle)
            ARG_COMMAND=unidle
            ;;
        --user)
            if [ -n "$2" ]; then
                ARG_USERNAME=$2
                shift
            else
                printf 'ERROR: "--user" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
        --project-suffix)
            if [ -n "$2" ]; then
                ARG_PROJECT_SUFFIX=$2
                shift
            else
                printf 'ERROR: "--project-suffix" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
        --domain-name)
            if [ -n "$2" ]; then
                ARG_DOMAIN_NAME=$2
                shift
            else
                printf 'ERROR: "--domain-name" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
        --oc-options)
            if [ -n "$2" ]; then
                ARG_OC_OPS=$2
                shift
            else
                printf 'ERROR: "--oc-options" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
        --ephemeral)
            ARG_EPHEMERAL=true
            ;;
        --use-sonar)
            ARG_WITH_SONAR=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            shift
            ;;
        *) # Default case: If no more options then break out of the loop.
            break
    esac

    shift
done


################################################################################
# CONFIGURATION                                                                #
################################################################################

LOGGEDIN_USER=$(oc $ARG_OC_OPS whoami)
OPENSHIFT_USER=${ARG_USERNAME:-$LOGGEDIN_USER}
PRJ_SUFFIX=${ARG_PROJECT_SUFFIX:-`echo $OPENSHIFT_USER | sed -e 's/[-@].*//g'`}
# GITHUB_ACCOUNT=${GITHUB_ACCOUNT:-OpenShiftDemos}
# GITHUB_REF=${GITHUB_REF:-ocp-3.7}

function deploy() {

  oc $ARG_OC_OPS new-project $PRJ_SUFFIX-kitchensink-sonarqube --display-name="Homework Kitchensink - SONARQUBE"
  oc $ARG_OC_OPS new-app -f https://raw.githubusercontent.com/OpenShiftDemos/sonarqube-openshift-docker/master/sonarqube-postgresql-template.yaml --param=SONARQUBE_VERSION=6.7 -n $PRJ_SUFFIX-kitchensink-sonarqube


  HOST_NAME=$PRJ_SUFFIX.$ARG_DOMAIN_NAME
  echo
  echo "HOST_NAME is [$HOST_NAME]"
  echo
  oc $ARG_OC_OPS new-project $PRJ_SUFFIX-kitchensink-gogs --display-name="Homework Kitchensink - Gogs"
  oc $ARG_OC_OPS new-app -f https://raw.githubusercontent.com/OpenShiftDemos/gogs-openshift-docker/master/openshift/gogs-persistent-template.yaml --param=HOSTNAME=$HOST_NAME -n $PRJ_SUFFIX-kitchensink-gogs


  oc $ARG_OC_OPS new-project $PRJ_SUFFIX-kitchensink-nexus --display-name="Homework Kitchensink - Nexus"
  oc $ARG_OC_OPS new-app -f https://raw.githubusercontent.com/OpenShiftDemos/nexus/master/nexus3-persistent-template.yaml -n $PRJ_SUFFIX-kitchensink-nexus


  oc $ARG_OC_OPS new-project $PRJ_SUFFIX-kitchensink-jenkins  --display-name="Homework Kitchensink - Jenkins"

  sleep 2
  # Import only if not available in the Openshift registry
  # oc import-image jenkins:v3.7 --from="registry.access.redhat.com/openshift3/jenkins-2-rhel7" --confirm -n openshift 2>/dev/null

  sleep 10

  # Create jenkins app
  #oc new-app jenkins-ephemeral --param=JENKINS_IMAGE_STREAM_TAG=jenkins:v3.7 -n $PRJ_SUFFIX-kitchensink-jenkins
  oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi --param VOLUME_CAPACITY=4Gi -n $PRJ_SUFFIX-kitchensink-jenkins

  # Create pipeline config
  oc create -f https://raw.githubusercontent.com/npatel2012/kitchensink-lab/master/kitchensink-pipeline.yaml -n $PRJ_SUFFIX-kitchensink-jenkins

  sleep 2

  #local template=https://raw.githubusercontent.com/$GITHUB_ACCOUNT/openshift-cd-demo/$GITHUB_REF/cicd-template.yaml
  #echo "Using template $template"
  #oc $ARG_OC_OPS new-app -f $template --param DEV_PROJECT=dev-$PRJ_SUFFIX --param STAGE_PROJECT=stage-$PRJ_SUFFIX --param=WITH_SONAR=$ARG_WITH_SONAR --param=EPHEMERAL=$ARG_EPHEMERAL -n cicd-$PRJ_SUFFIX

}

function make_idle() {
  echo_header "Idling Services"
  oc $ARG_OC_OPS idle -n $PRJ_SUFFIX-kitchensink-sonarqube --all
  oc $ARG_OC_OPS idle -n $PRJ_SUFFIX-kitchensink-gogs --all
  oc $ARG_OC_OPS idle -n $PRJ_SUFFIX-kitchensink-nexus --all
  oc $ARG_OC_OPS idle -n $PRJ_SUFFIX-kitchensink-jenkins --all
}

function make_unidle() {
  echo_header "Unidling Services"
  local _DIGIT_REGEX="^[[:digit:]]*$"

  for project in $PRJ_SUFFIX-kitchensink-sonarqube $PRJ_SUFFIX-kitchensink-gogs $PRJ_SUFFIX-kitchensink-nexus $PRJ_SUFFIX-kitchensink-jenkins
  do
    for dc in $(oc $ARG_OC_OPS get dc -n $project -o=custom-columns=:.metadata.name); do
      local replicas=$(oc $ARG_OC_OPS get dc $dc --template='{{ index .metadata.annotations "idling.alpha.openshift.io/previous-scale"}}' -n $project 2>/dev/null)
      if [[ $replicas =~ $_DIGIT_REGEX ]]; then
        oc $ARG_OC_OPS scale --replicas=$replicas dc $dc -n $project
      fi
    done
  done
}

function set_default_project() {
  if [ $LOGGEDIN_USER == 'system:admin' ] ; then
    oc $ARG_OC_OPS project default >/dev/null
  fi
}

function remove_storage_claim() {
  local _DC=$1
  local _VOLUME_NAME=$2
  local _CLAIM_NAME=$3
  local _PROJECT=$4
  oc $ARG_OC_OPS volumes dc/$_DC --name=$_VOLUME_NAME --add -t emptyDir --overwrite -n $_PROJECT
  oc $ARG_OC_OPS delete pvc $_CLAIM_NAME -n $_PROJECT >/dev/null 2>&1
}

function echo_header() {
  echo
  echo "########################################################################"
  echo $1
  echo "########################################################################"
}

################################################################################
# MAIN: DEPLOY DEMO                                                            #
################################################################################

if [ "$LOGGEDIN_USER" == 'system:admin' ] && [ -z "$ARG_USERNAME" ] ; then
  # for verify and delete, --project-suffix is enough
  if [ "$ARG_COMMAND" == "delete" ] || [ "$ARG_COMMAND" == "verify" ] && [ -z "$ARG_PROJECT_SUFFIX" ]; then
    echo "--user or --project-suffix must be provided when running $ARG_COMMAND as 'system:admin'"
    exit 255
  # deploy command
  elif [ "$ARG_COMMAND" != "delete" ] && [ "$ARG_COMMAND" != "verify" ] ; then
    echo "--user must be provided when running $ARG_COMMAND as 'system:admin'"
    exit 255
  fi
fi

pushd ~ >/dev/null
START=`date +%s`

echo_header "OpenShift Kitchensink CI/CD Demo ($(date))"

case "$ARG_COMMAND" in
    delete)
        echo "Delete demo..."
        oc $ARG_OC_OPS delete project $PRJ_SUFFIX-kitchensink-sonarqube $PRJ_SUFFIX-kitchensink-gogs $PRJ_SUFFIX-kitchensink-nexus $PRJ_SUFFIX-kitchensink-jenkins
        echo
        echo "Delete completed successfully!"
        ;;

    idle)
        echo "Idling demo..."
        make_idle
        echo
        echo "Idling completed successfully!"
        ;;

    unidle)
        echo "Unidling demo..."
        make_unidle
        echo
        echo "Unidling completed successfully!"
        ;;

    deploy)
        echo "Deploying demo..."
        deploy
        echo
        echo "Provisioning completed successfully!"
        ;;

    *)
        echo "Invalid command specified: '$ARG_COMMAND'"
        usage
        ;;
esac

set_default_project
popd >/dev/null

END=`date +%s`
echo "(Completed in $(( ($END - $START)/60 )) min $(( ($END - $START)%60 )) sec)"
echo
