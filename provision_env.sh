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
    echo
}

ARG_USERNAME=
ARG_PROJECT_SUFFIX=
ARG_COMMAND=
ARG_EPHEMERAL=false
ARG_OC_OPS=
ARG_WITH_SONAR=false

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
  oc $ARG_OC_OPS new-project $PRJ_SUFFIX-kitchensink-dev --display-name="Homework Kitchensink - Dev"
  oc $ARG_OC_OPS new-project $PRJ_SUFFIX-kitchensink-stage --display-name="Homework Kitchensink - Stage"
  oc $ARG_OC_OPS new-project $PRJ_SUFFIX-kitchensink-prod --display-name="Homework Kitchensink - Production"

  # oc $ARG_OC_OPS new-project dev-$PRJ_SUFFIX   --display-name="Kitchensink - Dev"
  # oc $ARG_OC_OPS new-project stage-$PRJ_SUFFIX --display-name="Kitchensink - Stage"
  # oc $ARG_OC_OPS new-project prod-$PRJ_SUFFIX --display-name="Kitchensink - Production"
  # oc $ARG_OC_OPS new-project cicd-$PRJ_SUFFIX  --display-name="Kitchensink CI/CD"

  sleep 2

  # Setting necessary policies
  oc $ARG_OC_OPS policy add-role-to-user edit system:serviceaccount:npatel-jenkins:jenkins -n $PRJ_SUFFIX-kitchensink-dev
  oc $ARG_OC_OPS policy add-role-to-user edit system:serviceaccount:npatel-jenkins:jenkins -n $PRJ_SUFFIX-kitchensink-stage
  oc $ARG_OC_OPS policy add-role-to-user edit system:serviceaccount:npatel-jenkins:jenkins -n $PRJ_SUFFIX-kitchensink-prod
  oc $ARG_OC_OPS policy add-role-to-group system:image-puller system:serviceaccounts:$PRJ_SUFFIX-kitchensink-prod -n $PRJ_SUFFIX-kitchensink-prod
  oc $ARG_OC_OPS policy add-role-to-user edit system:serviceaccount:npatel-jenkins:jenkins -n $PRJ_SUFFIX-kitchensink-prod


  # Setting up the DEVELOPMENT ENVIRONMENT
  oc project $PRJ_SUFFIX-kitchensink-dev
  oc new-build --binary=true --name="kitchensink" jboss-eap70-openshift:1.5 -n $PRJ_SUFFIX-kitchensink-dev
  oc new-app $PRJ_SUFFIX-kitchensink-dev/kitchensink:TestingKitchensink-1.0 --name=kitchensink --allow-missing-imagestream-tags=true -n $PRJ_SUFFIX-kitchensink-dev
  oc set triggers dc/kitchensink --manual -n $PRJ_SUFFIX-kitchensink-dev
  oc expose dc kitchensink --port=8080 -n $PRJ_SUFFIX-kitchensink-dev
  oc expose svc kitchensink -n $PRJ_SUFFIX-kitchensink-dev

  # Setting up the STAGING ENVIRONMENT
  oc project $PRJ_SUFFIX-kitchensink-stage
  oc new-app $PRJ_SUFFIX-kitchensink-dev/kitchensink:StagingKitchensink-1.0 --name=kitchensink --allow-missing-imagestream-tags=true -n $PRJ_SUFFIX-kitchensink-stage
  oc set triggers dc/kitchensink --manual -n $PRJ_SUFFIX-kitchensink-stage
  oc expose dc kitchensink --port=8080 -n $PRJ_SUFFIX-kitchensink-stage
  oc expose svc kitchensink -n $PRJ_SUFFIX-kitchensink-stage

  # Setting up the PRODUCTION ENVIRONMENT
  oc project $PRJ_SUFFIX-kitchensink-prod
  oc new-app $PRJ_SUFFIX-kitchensink-dev/kitchensink:ProdReady-1.0 --name=kitchensink-green --allow-missing-imagestream-tags=true -n $PRJ_SUFFIX-kitchensink-prod
  oc new-app $PRJ_SUFFIX-kitchensink-dev/kitchensink:ProdReady-1.0 --name=kitchensink-blue --allow-missing-imagestream-tags=true -n $PRJ_SUFFIX-kitchensink-prod
  oc set triggers dc/kitchensink-green --manual -n $PRJ_SUFFIX-kitchensink-prod
  oc set triggers dc/kitchensink-blue --manual -n $PRJ_SUFFIX-kitchensink-prod
  oc expose dc kitchensink-green --port 8080 -n $PRJ_SUFFIX-kitchensink-prod
  oc expose dc kitchensink-blue --port 8080 -n $PRJ_SUFFIX-kitchensink-prod
  oc expose svc/kitchensink-green --name kitchensink -n $PRJ_SUFFIX-kitchensink-prod

  sleep 2

  # Import only if not available in the Openshift registry
  # oc import-image jenkins:v3.7 --from="registry.access.redhat.com/openshift3/jenkins-2-rhel7" --confirm -n openshift 2>/dev/null

  sleep 10

  # oc new-app jenkins-ephemeral --param=JENKINS_IMAGE_STREAM_TAG=jenkins:v3.7 -n cicd-$PRJ_SUFFIX

  sleep 2

  #local template=https://raw.githubusercontent.com/$GITHUB_ACCOUNT/openshift-cd-demo/$GITHUB_REF/cicd-template.yaml
  #echo "Using template $template"
  #oc $ARG_OC_OPS new-app -f $template --param DEV_PROJECT=dev-$PRJ_SUFFIX --param STAGE_PROJECT=stage-$PRJ_SUFFIX --param=WITH_SONAR=$ARG_WITH_SONAR --param=EPHEMERAL=$ARG_EPHEMERAL -n cicd-$PRJ_SUFFIX

}

function make_idle() {
  echo_header "Idling Services"
  oc $ARG_OC_OPS idle -n $PRJ_SUFFIX-kitchensink-dev --all
  oc $ARG_OC_OPS idle -n $PRJ_SUFFIX-kitchensink-stage --all
  oc $ARG_OC_OPS idle -n $PRJ_SUFFIX-kitchensink-prod --all
}

function make_unidle() {
  echo_header "Unidling Services"
  local _DIGIT_REGEX="^[[:digit:]]*$"

  for project in $PRJ_SUFFIX-kitchensink-dev $PRJ_SUFFIX-kitchensink-stage $PRJ_SUFFIX-kitchensink-prod
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
        oc $ARG_OC_OPS delete project $PRJ_SUFFIX-kitchensink-dev $PRJ_SUFFIX-kitchensink-stage $PRJ_SUFFIX-kitchensink-prod
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
