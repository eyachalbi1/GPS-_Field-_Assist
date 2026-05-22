#!/bin/bash
#
# Configuration automatique du job Jenkins pour GPS Field Assist
# Crée le pipeline Jenkins avec les bonnes configurations
#

set -e

JENKINS_URL="${JENKINS_URL:-http://localhost:9090}"
JOB_NAME="gps-field-assist"
GIT_REPO="${GIT_REPO:-$(git config --get remote.origin.url)}"

echo "=== Configuration du job Jenkins ==="
echo "Jenkins URL: ${JENKINS_URL}"
echo "Job name: ${JOB_NAME}"
echo "Git repo: ${GIT_REPO}"
echo ""

# Vérifier que Jenkins est accessible
if ! curl -s "${JENKINS_URL}" >/dev/null 2>&1; then
    echo "ERREUR: Jenkins n'est pas accessible sur ${JENKINS_URL}"
    echo "Démarrez d'abord: docker-compose up -d jenkins"
    exit 1
fi

# Récupérer le crumb CSRF (sécurité Jenkins)
JENKINS_CRUMB=$(curl -s "${JENKINS_URL}/crumbIssuer/api/xml?xpath=//crumb" 2>/dev/null || echo "")

if [ -z "${JENKINS_CRUMB}" ]; then
    echo "ERREUR: Impossible d'obtenir le crumb Jenkins. Vérifiez que Jenkins est initialisé."
    echo "Premier accès: ${JENKINS_URL}"
    exit 1
fi

echo "Crumb obtenu: ${JENKINS_CRUMB}"

# Configuration XML du job Pipeline
JOB_CONFIG='<?xml version="1.0" encoding="UTF-8"?>
<flow-definition plugin="workflow-job@2.40">
  <actions/>
  <description>Pipeline CI/CD pour GPS Field Assist - Build backend + mobile</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.pipeline.modeldefinition.config.FolderConfig plugin="pipeline-model-definition@1.8.0">
      <dockerLabel></dockerLabel>
      <registry></registry>
    </org.jenkinsci.plugins.pipeline.modeldefinition.config.FolderConfig>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.80">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@4.10.0">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>' + GIT_REPO + '</url>
          <credentialsId>git-credentials</credentialsId>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers>
    <org.jenkinsci.plugins.github.webhook.GitHubPushTrigger plugin="github@1.34.0"/>
  </triggers>
  <disabled>false</disabled>
</flow-definition>'

# Créer le job via Jenkins API
echo "Création du job Jenkins..."
curl -s -X POST "${JENKINS_URL}/createItem?name=${JOB_NAME}" \
  -H "Jenkins-Crumb: ${JENKINS_CRUMB}" \
  -H "Content-Type: application/xml" \
  -d "${JOB_CONFIG}" \
  -o /dev/null

if [ $? -eq 0 ]; then
    echo "✓ Job Jenkins '${JOB_NAME}' créé avec succès"
else
    echo "⚠️  Le job existe peut-être déjà, tentative de mise à jour..."
    curl -s -X POST "${JENKINS_URL}/job/${JOB_NAME}/config.xml" \
      -H "Jenkins-Crumb: ${JENKINS_CRUMB}" \
      -H "Content-Type: application/xml" \
      -d "${JOB_CONFIG}" \
      -o /dev/null
fi

# Activer les triggers GitHub (webhook)
echo "Configuration des triggers..."
curl -s -X POST "${JENKINS_URL}/job/${JOB_NAME}/configure" \
  -H "Jenkins-Crumb: ${JENKINS_CRUMB}" \
  -H "Content-Type: application/xml" \
  -d "${JOB_CONFIG}" \
  -o /dev/null || true

echo ""
echo "=== Configuration terminée ==="
echo ""
echo "Prochaines étapes:"
echo "1. Connectez-vous à Jenkins: ${JENKINS_URL}"
echo "2. Allez dans 'Manage Jenkins' → 'Manage Credentials'"
echo "3. Ajoutez les credentials Git:"
echo "   - Kind: Username with password"
echo "   - Username: votre_username_github"
echo "   - Password: votre_personal_access_token"
echo "   - ID: git-credentials"
echo ""
echo "4. Dans le job '${JOB_NAME}', cliquez sur 'Build Now'"
echo ""
echo "Le pipeline s'exécutera automatiquement à chaque push sur main."
