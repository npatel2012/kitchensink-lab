#!groovy

// Run this node on a Maven Slave
// Maven Slaves have JDK and Maven already installed
node('maven') {
  // Make sure your nexus_openshift_settings.xml
  // Is pointing to your nexus instance
  def mvnCmd = "mvn -s ./nexus_openshift_settings.xml"
  def devProjectName = "test-npatel-kitchensink-dev"
  def stagingProjectName = "test-npatel-kitchensink-stage"
  def productionProjectName = "test-npatel-kitchensink-prod"
  def sonarqubeProjectName = "test-npatel-kitchensink-sonarqube"
  def gogsProjectName = "test-npatel-kitchensink-gogs"
  def nexusProjectName = "test-npatel-kitchensink-nexus"
  def jenkinsProjectName = "test-npatel-kitchensink-jenkins"

  stage('Checkout Source') {
    // Get Source Code from SCM (Git) as configured in the Jenkins Project
    // Next line for inline script, "checkout scm" for Jenkinsfile from Gogs
    // git 'http://gogs.npatel-gogs.svc.cluster.local:3000/CICDLabs/kitchensink.git'
    checkout scm
    sh("git config --global user.email 'developer@redhat.com'")
    sh("git config --global user.name 'Niraj Patel'")
    sh("git tag -a 7.0.'${currentBuild.number}' -m 'Jenkins'")
    // sh('git push http://developer:developer@gogs.${gogsProjectName}.svc.cluster.local:3000/CICDLabs/kitchensink.git --tags')
    sh('git push http://developer:developer@test-npatel.apps.2245.openshift.opentlc.com/CICDLabs/kitchensink.git --tags')
  }

  // The following variables need to be defined at the top level and not inside
  // the scope of a stage - otherwise they would not be accessible from other stages.
  // Extract version and other properties from the pom.xml
  def groupId    = getGroupIdFromPom("pom.xml")
  def artifactId = getArtifactIdFromPom("pom.xml")
  //def version    = getVersionFromPom("pom.xml")
  def version    = "7.0.${currentBuild.number}"

  stage('Build war') {
    echo "Building version ${version}"

	sh "${mvnCmd} versions:set -DnewVersion=7.0.${version}"
    sh "${mvnCmd} clean package -DskipTests"
  }
  stage('Unit Tests') {
    echo "Unit Tests"
    sh "${mvnCmd} test"
  }
  stage('Code Analysis') {
    echo "Code Analysis"

    // Replace xyz-sonarqube with the name of your project
    // sh "${mvnCmd} sonar:sonar -Dsonar.host.url=http://sonarqube.${sonarqubeProjectName}.svc.cluster.local:9000/ -Dsonar.projectName=${JOB_BASE_NAME}"
  }
  stage('Publish to Nexus') {
    echo "Publish to Nexus"

    // Replace xyz-nexus with the name of your project
    // sh "${mvnCmd} deploy -DskipTests=true -DaltDeploymentRepository=nexus::default::http://nexus3.${nexusProjectName}.svc.cluster.local:8081/repository/releases"
  }

  stage('Build OpenShift Image') {
    def newTag = "TestingKitchensink-${version}"
    echo "New Tag: ${newTag}"

    // Copy the war file we just built and rename to ROOT.war
    sh "cp ./target/jboss-kitchensink-angularjs.war ./ROOT.war"

    // Start Binary Build in OpenShift using the file we just published
    // Replace xyz-tasks-dev with the name of your dev project
    sh "oc whoami"
    sh "oc project ${devProjectName}"
    sh "oc start-build kitchensink --follow --from-file=./ROOT.war -n ${devProjectName}"

    openshiftTag alias: 'false', destStream: 'kitchensink', destTag: newTag, destinationNamespace: '${devProjectName}', namespace: '${devProjectName}', srcStream: 'kitchensink', srcTag: 'latest', verbose: 'false'
  }

  stage('Deploy to Dev') {
    // Patch the DeploymentConfig so that it points to the latest TestingCandidate-${version} Image.
    // Replace xyz-tasks-dev with the name of your dev project
    sh "oc project ${devProjectName}"
    sh "oc patch dc kitchensink --patch '{\"spec\": { \"triggers\": [ { \"type\": \"ImageChange\", \"imageChangeParams\": { \"containerNames\": [ \"kitchensink\" ], \"from\": { \"kind\": \"ImageStreamTag\", \"namespace\": \"${devProjectName}\", \"name\": \"kitchensink:TestingKitchensink-$version\"}}}]}}' -n ${devProjectName}"

    openshiftDeploy depCfg: 'kitchensink', namespace: '${devProjectName}', verbose: 'false', waitTime: '', waitUnit: 'sec'
    openshiftVerifyDeployment depCfg: 'kitchensink', namespace: '${devProjectName}', replicaCount: '1', verbose: 'false', verifyReplicaCount: 'false', waitTime: '', waitUnit: 'sec'
    openshiftVerifyService namespace: '${devProjectName}', svcName: 'kitchensink', verbose: 'false'
  }

  stage('Integration Test') {
    // TBD: Proper test
    // Could use the OpenShift-Tasks REST APIs to make sure it is working as expected.

    //def newTag = "ProdReady-${version}"
    def newTag = "StagingKitchensink-${version}"
    echo "New Tag: ${newTag}"

    // Replace xyz-tasks-dev with the name of your dev project
    openshiftTag alias: 'false', destStream: 'kitchensink', destTag: newTag, destinationNamespace: '${devProjectName}', namespace: '${devProjectName}', srcStream: 'kitchensink', srcTag: 'latest', verbose: 'false'
  }

  stage('Deploy to Staging'){
    sh "oc project ${stagingProjectName}"
    sh "oc patch dc kitchensink --patch '{\"spec\": { \"triggers\": [ { \"type\": \"ImageChange\", \"imageChangeParams\": { \"containerNames\": [ \"kitchensink\" ], \"from\": { \"kind\": \"ImageStreamTag\", \"namespace\": \"${devProjectName}\", \"name\": \"kitchensink:StagingKitchensink-$version\"}}}]}}' -n ${stagingProjectName}"

    openshiftDeploy depCfg: 'kitchensink', namespace: '${stagingProjectName}', verbose: 'false', waitTime: '', waitUnit: 'sec'
    openshiftVerifyDeployment depCfg: 'kitchensink', namespace: '${stagingProjectName}', replicaCount: '1', verbose: 'false', verifyReplicaCount: 'false', waitTime: '', waitUnit: 'sec'
    openshiftVerifyService namespace: '${stagingProjectName}', svcName: 'kitchensink', verbose: 'false'

  }

  stage('Build Prod Tag'){
    def newTag = "ProdReady-${version}"
    echo "New Tag: ${newTag}"

    openshiftTag alias: 'false', destStream: 'kitchensink', destTag: newTag, destinationNamespace: '${devProjectName}', namespace: '${devProjectName}', srcStream: 'kitchensink', srcTag: 'latest', verbose: 'false'
  }

  // Blue/Green Deployment into Production
  // -------------------------------------
  def dest   = "kitchensink-green"
  def active = ""

  stage('Prep Production Deployment') {
    // Replace xyz-tasks-dev and xyz-tasks-prod with
    // your project names
    sh "oc project ${productionProjectName}"
    sh "oc get route kitchensink -n ${productionProjectName} -o jsonpath='{ .spec.to.name }' > activesvc.txt"
    active = readFile('activesvc.txt').trim()
    if (active == "kitchensink-green") {
      dest = "kitchensink-blue"
    }
    echo "Active svc: " + active
    echo "Dest svc:   " + dest
  }
  stage('Deploy new Version') {
    echo "Deploying to ${dest}"

    // Patch the DeploymentConfig so that it points to
    // the latest ProdReady-${version} Image.
    // Replace xyz-tasks-dev and xyz-tasks-prod with
    // your project names.
    sh "oc patch dc ${dest} --patch '{\"spec\": { \"triggers\": [ { \"type\": \"ImageChange\", \"imageChangeParams\": { \"containerNames\": [ \"$dest\" ], \"from\": { \"kind\": \"ImageStreamTag\", \"namespace\": \"${devProjectName}\", \"name\": \"kitchensink:ProdReady-$version\"}}}]}}' -n ${productionProjectName}"

    openshiftDeploy depCfg: dest, namespace: '${productionProjectName}', verbose: 'false', waitTime: '', waitUnit: 'sec'
    openshiftVerifyDeployment depCfg: dest, namespace: '${productionProjectName}', replicaCount: '1', verbose: 'false', verifyReplicaCount: 'true', waitTime: '', waitUnit: 'sec'
    openshiftVerifyService namespace: '${productionProjectName}', svcName: dest, verbose: 'false'
  }
  stage('Switch over to new Version') {
    input "Switch Production?"

    // Replace xyz-tasks-prod with the name of your
    // production project
    sh 'oc patch route kitchensink -n ${productionProjectName} -p \'{"spec":{"to":{"name":"' + dest + '"}}}\''
    sh 'oc get route kitchensink -n ${productionProjectName} > oc_out.txt'
    oc_out = readFile('oc_out.txt')
    echo "Current route configuration: " + oc_out
  }
}

// Convenience Functions to read variables from the pom.xml
def getVersionFromPom(pom) {
  def matcher = readFile(pom) =~ '<version>(.+)</version>'
  matcher ? matcher[0][1] : null
}
def getGroupIdFromPom(pom) {
  def matcher = readFile(pom) =~ '<groupId>(.+)</groupId>'
  matcher ? matcher[0][1] : null
}
def getArtifactIdFromPom(pom) {
  def matcher = readFile(pom) =~ '<artifactId>(.+)</artifactId>'
  matcher ? matcher[0][1] : null
}
