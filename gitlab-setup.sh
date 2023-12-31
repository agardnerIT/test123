===================================
Gitlab config

# Create Gitlab PAT
# - Select avatar > edit profile
# - Access tokens > add new token
# - Choose "api" permission
# - Choose date in future
# - Click "create pat"
export GL_PAT=glpat-******
git_user=root
git_pwd=$GL_PAT
git_email=admin@example.com
git_repo=app1-template

# Get all users (testing)
#curl -H "PRIVATE-TOKEN: $GL_PAT" -X GET https://gitlab.dtu-test-s17-2afbea.dynatrace.training/api/v4/users

# Create a user
# Gitlab disallows:
# - Passwords < 8 chars
# - Passwords containing dictionary words
# Password is therefore "hotdaytraining123" with all vowels removed
curl -X POST -d '{"name": "user1", "password": "htdytrnng", "username": "user1", "email": "user1@dynatrace.training" }' -H "Content-Type: application/json" -H "PRIVATE-TOKEN: $GL_PAT" "https://gitlab.dtu-test-s17-2afbea.dynatrace.training/api/v4/users"
curl -X POST -d '{"name": "user2", "password": "htdytrnng", "username": "user2", "email": "user2@dynatrace.training" }' -H "Content-Type: application/json" -H "PRIVATE-TOKEN: $GL_PAT" "https://gitlab.dtu-test-s17-2afbea.dynatrace.training/api/v4/users"
...

# Create empty template repo (project)
curl -X POST -d '{"name": "'$git_repo'", "initialize_with_readme": true, "visibility": "public"}' -H "Content-Type: application/json" -H "PRIVATE-TOKEN: $GL_PAT" "https://gitlab.dtu-test-s17-2afbea.dynatrace.training/api/v4/projects"

# Add files


git config --global user.email "$git_email" && git config --global user.name "$git_user"
git clone http://gitlab.dtu-test-s17-2afbea.dynatrace.training/$git_user/$git_repo.git
cd $git_repo
cat <<EOF > namespace.yml
---
apiVersion: v1
kind: Namespace
metadata:
  name: $git_repo
  labels:
    dt.owner: "appteamX"
  annotations:
    keptn.sh/lifecycle-toolkit: enabled
EOF
cat <<EOF > service.yml
---
apiVersion: v1
kind: Service
metadata:
  name: rollout-demo
  namespace: $git_repo
  labels:
    dt.owner: "appteamX"
spec:
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app.kubernetes.io/name: userinterface
EOF
cat <<EOF > rollout.yml
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: rollouts-demo
  namespace: $git_repo
  labels:
    dt.owner: "appteamX"
spec:
  replicas: 5
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 2s}
      - setWeight: 40
      - pause: {duration: 2s}
      - setWeight: 60
      - pause: {duration: 2s}
      - setWeight: 80
      - pause: {duration: 2s}
  revisionHistoryLimit: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: userinterface
  template:
    metadata:
      labels:
        app.kubernetes.io/name: userinterface
        app.kubernetes.io/part-of: MyApp
        app.kubernetes.io/version: v1.0.2
        dynatrace-release-stage: preprod
    spec:
      containers:
      - name: rollouts-demo
        image: grabnerandi/simplenodeservice:1.0.2
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
EOF
cat <<EOF > ingress.yml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $git_repo
  namespace: $git_repo
  labels:
    dt.owner: "appteamX"
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
spec:
  rules:
    - host: $git_repo.dtu-test-s17-2afbea.dynatrace.training
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: rollout-demo
                port:
                  number: 80
EOF
cat <<EOF> workflow-post-sync-apply-monaco.yml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: wf-apply-monaco-
  namespace: monaco
  labels:
    workflows.argoproj.io/archive-strategy: "false"
  annotations:
    workflows.argoproj.io/description: |
      This workflow runs DT Monaco
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  entrypoint: git-clone
  templates:
  - name: git-clone
    inputs:
      artifacts:
      - name: git-files
        path: /src
        git:
          repo: http://gitlab.dtu-test-s17-2afbea.dynatrace.training/$git_user/$git_repo.git
    container:
      image: dynatrace/dynatrace-configuration-as-code:latest
      args: [
        "deploy",
        "/src/monaco/manifest.yml",
        "--environment",
        "prod-api-and-oauth",
        "--project",
        "configure-dt"
      ]
      env:
      - name: monacoToken
        valueFrom:
          secretKeyRef:
            name: monaco-secret
            key: monacoToken
      - name: MONACO_OAUTH_CLIENT_ID
        valueFrom:
          secretKeyRef:
            name: srg-oauth-details
            key: oAuthClientID
      - name: MONACO_OAUTH_CLIENT_SECRET
        valueFrom:
          secretKeyRef:
            name: srg-oauth-details
            key: oAuthClientSecret
      workingDir: /src
EOF
mkdir --parents monaco/configure-dt/owners
mkdir --parents monaco/configure-dt/slos
cat <<EOF > monaco/manifest.yml
manifestVersion: 1.0
projects:
  - name: configure-dt
    path: configure-dt
environmentGroups:
  - name: development
    environments:
      - name: prod-api-token-only
        # .live. when using API token only
        # .apps. when using API + oAuth or just oAuth
        url:
          value: "https://wls34801.live.dynatrace.com"
        auth:
          token:
            name: "monacoToken" 
      - name: prod-api-and-oauth
        url:
          value: "https://wls34801.apps.dynatrace.com"
        auth:
          token:
            name: "monacoToken"
          oAuth:
            clientId:
              name: MONACO_OAUTH_CLIENT_ID
            clientSecret:
              name: MONACO_OAUTH_CLIENT_SECRET
EOF
cat <<EOF > monaco/configure-dt/owners/owners.yml
configs:
- id: appteamX
  type:
    settings:
      schema: builtin:ownership.teams
      scope: environment
  config:
    name: app team X
    template: appteam.json
    parameters:
      descr: Application team X
      team_id: appteamX
      development: true
      security: false
      operations: true
      infrastructure: false
      lineOfBusiness: false
      slackChannel: somewhere
      slackURL: https://somewhere.slack.com/archives/ABC1234
      email: appteamX@example.com
      addInfoKey: costcode
      addInfoValue: appteamX
      addInfoUrl: https://example.com/appTeamX
    skip: false
EOF
cat <<EOF > monaco/configure-dt/owners/appteam.json
{
    "name":"{{ .name }}",
    "description":"{{ .descr }}",
    "identifier":"{{ .team_id }}",
    "responsibilities":
    {
        "development": {{ .development }},
        "security":{{ .security }},
        "operations":{{ .operations }},
        "infrastructure":{{ .infrastructure }},
        "lineOfBusiness":{{ .lineOfBusiness }}
    },
        "contactDetails": [
            {
                "integrationType":"SLACK",
                "slackChannel":"{{ .slackChannel }}",
                "url":"{{ .slackURL }}"
            },
            {
                "integrationType":"EMAIL",
                "email":"{{ .email }}"
            }
        ],
         "links":[],
    "additionalInformation":
    [
        {
            "key":"{{ .addInfoKey }}",
            "value":"{{ .addInfoValue }}", 
            "url":"{{ .addInfoUrl }}"
        }
    ]
}
EOF
cat <<EOF > monaco/configure-dt/slos/slo.json
{
  "enabled": true,
  "name": "{{ .name }}",
  "metricName": "{{ .metricName }}",
  "metricExpression": "{{ .metricExpression }}",
  "evaluationType": "AGGREGATE",
  "filter": "{{ .filter }}",
  "evaluationWindow": "-1w",
  "targetSuccess": {{ .thresholdTarget }},
  "targetWarning": {{ .thresholdWarning }},
  "errorBudgetBurnRate": {
      "burnRateVisualizationEnabled": true,
      "fastBurnThreshold": 10
  }
}
EOF
cat <<EOF > monaco/configure-dt/slos/slo.yml
configs:
- id: sns_slo
  config:
    name: SNS Availability
    parameters:
      metricName: sns_availability
      metricExpression: "(100)*(builtin:service.errors.server.successCount:splitBy())/(builtin:service.requestCount.server:splitBy())"
      filter: "type(SERVICE), entityName.equals(SimpleNodeJsService)"
      thresholdTarget: "99.98"
      thresholdWarning: "99.99"
    template: slo.json
    skip: false
  type:
    api: slo
EOF
git add -A
git commit -m "initial commit"
git push https://$git_user:$git_pwd@gitlab.dtu-test-s17-2afbea.dynatrace.training/$git_user/$git_repo.git


# This is from the 'alice' user (see argocd-cm)
# AFAICT although the user is created via GitOps
# The token must be created manually
ARGOCD_TOKEN=eyJ****
kubectl -n backstage create secret generic backstage-secrets --from-literal=GITLAB_TOKEN=$GL_PAT --from-literal=ARGOCD_TOKEN=$ARGO_TOKEN