#!/usr/bin/env python3
"""
Script pour créer automatiquement le job Jenkins via l'API REST.
Usage : python setup_jenkins_job.py
"""
import requests
import sys

JENKINS_URL = "http://localhost:9090"
JOB_NAME    = "gps-field-assist"

JOB_CONFIG_XML = """<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Pipeline CI/CD GPS Field Assist — Backend + Flutter APK</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <hudson.triggers.SCMTrigger>
          <spec>H/5 * * * *</spec>
        </hudson.triggers.SCMTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition"
              plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>GIT_REPO_URL</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <disabled>false</disabled>
</flow-definition>"""


def create_job(git_url: str):
    config = JOB_CONFIG_XML.replace("GIT_REPO_URL", git_url)
    url = f"{JENKINS_URL}/createItem?name={JOB_NAME}"
    headers = {"Content-Type": "application/xml"}
    resp = requests.post(url, data=config.encode("utf-8"), headers=headers)
    if resp.status_code in [200, 201]:
        print(f"✅ Job '{JOB_NAME}' créé : {JENKINS_URL}/job/{JOB_NAME}")
    elif resp.status_code == 400:
        print(f"⚠️  Job '{JOB_NAME}' existe déjà.")
    else:
        print(f"❌ Erreur {resp.status_code} : {resp.text}")
        sys.exit(1)


if __name__ == "__main__":
    git_url = input("URL du dépôt Git (ex: https://github.com/user/repo.git) : ").strip()
    if not git_url:
        print("❌ URL Git manquante.")
        sys.exit(1)
    create_job(git_url)
