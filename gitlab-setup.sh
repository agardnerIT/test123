#
# DEPRECATED. FOLLOW INSTRUCTIONS IN README.md
#
#
#

################################################################
###################
# GitLab          #
###################

# Manual step
# !! IMPORTANT: This is MANDATORY for backstage to work!!
# TODO: Figure out if / how to automate
# Log into GitLab
# Go to https://gitlab........dynatrace.training/admin/application_settings/general
# Change the "Custom Git clone URL for HTTP(S)" from "http://..." to "https://"

# Create Gitlab PAT
# - Select avatar > edit profile
# - Access tokens > add new token
# - Choose "api, read_repository and write_repository" permissions
# - Choose date in future
# - Click "create pat"
GL_PAT="glpat-*********"
REPO_TO_CLONE="https://github.com/agardnerit/test123" # TODO update once migrated to "proper" repo
DOMAIN="dtu-test-s17-2afbea.dynatrace.training"
GIT_USER="root"
GIT_PWD="$GL_PAT"
GIT_EMAIL="admin@example.com"
GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME="backstage-templates"
GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME="applications-template"

# Get all users (testing)
#curl -H "PRIVATE-TOKEN: $GL_PAT" -X GET https://gitlab.$DOMAIN/api/v4/users

# Create a user
# Gitlab disallows:
# - Passwords < 8 chars
# - Passwords containing dictionary words
# Password is therefore "hotdaytraining123" with all vowels removed
#curl -X POST -d '{"name": "user1", "password": "htdytrnng", "username": "user1", "email": "user1@dynatrace.training" }' -H "Content-Type: application/json" -H "PRIVATE-TOKEN: $GL_PAT" "https://gitlab.$DOMAIN/api/v4/users"
#curl -X POST -d '{"name": "user2", "password": "htdytrnng", "username": "user2", "email": "user2@dynatrace.training" }' -H "Content-Type: application/json" -H "PRIVATE-TOKEN: $GL_PAT" "https://gitlab.$DOMAIN/api/v4/users"
...

# Create empty template repo for backstage templates
curl -X POST -d '{"name": "'$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME'", "initialize_with_readme": true, "visibility": "public"}' -H "Content-Type: application/json" -H "PRIVATE-TOKEN: $GL_PAT" "https://gitlab.$DOMAIN/api/v4/projects"
# Create empty template repo for app templates
curl -X POST -d '{"name": "'$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME'", "initialize_with_readme": true, "visibility": "public"}' -H "Content-Type: application/json" -H "PRIVATE-TOKEN: $GL_PAT" "https://gitlab.$DOMAIN/api/v4/projects"

# Clone files from template GitHub.com repo
git config --global user.email "$GIT_EMAIL" && git config --global user.name "$GIT_USER"
# Ensure terminal is in home directory
cd
# Clone template files
git clone $REPO_TO_CLONE
# Clone new empty repo for backstage templates
git clone https://gitlab.$DOMAIN/$GIT_USER/$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME.git
# Clone new empty repo for app templates
git clone https://gitlab.$DOMAIN/$GIT_USER/$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME.git
# Copy files from template for backstage templates repo
# Then commit and push files
cp -R test123/backstagetemplates ./$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME
cd ./$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME
git add -A
git commit -m "initial commit"
git push https://$GIT_USER:$GIT_PWD@gitlab.$DOMAIN/$GIT_USER/$GIT_REPO_BACKSTAGE_TEMPLATES_TEMPLATE_NAME.git
# Copy files from template
cd
cp -R test123/apptemplates ./$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME
cd ./$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME
git add -A
git commit -m "initial commit"
git push https://$GIT_USER:$GIT_PWD@gitlab.$DOMAIN/$GIT_USER/$GIT_REPO_APP_TEMPLATES_TEMPLATE_NAME.git
# Done creating "backstage template" repo
# Done creating "applications template" repo

# How to: check if a group exists
# https://gitlab.BASE_DOMAIN_PLACEHOLDER/api/v4/namespaces/group2/exists?parent_id=

# Create 'group1'
# This group is where the backstage bootstrap process will create the "app teams" projects
# TODO: Rename to something more logical like "projects" or "teamprojects"
curl -X POST -d '{ "name": "group1", "path": "group1", "visibility": "public" }' -H "Content-Type: application/json" -H "PRIVATE-TOKEN: $GL_PAT" "https://gitlab.$DOMAIN/api/v4/groups"
# Add files

#######################
# BACKSTAGE
#######################
# This is from the 'alice' user (see argocd-cm)
# Set the default context to the argocd namespace so 'argocd' CLI works
kubectl config set-context --current --namespace=argocd
ARGOCD_TOKEN="argocd.token=$(argocd account generate-token --account alice)"
# Reset the context to 'default' namespace
kubectl config set-context --current --namespace=default 
kubectl -n backstage create secret generic backstage-secrets --from-literal=GITLAB_TOKEN=$GL_PAT --from-literal=ARGOCD_TOKEN=$ARGOCD_TOKEN