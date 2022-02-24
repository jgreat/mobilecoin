{{/*
Expand the name of the chart.
*/}}
{{- define "chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chart.labels" -}}
helm.sh/chart: {{ include "chart.chart" . }}
{{ include "chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "chart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database ConfigMap Name
*/}}
{{- define "chart.recoveryDatabaseConfigMapName" -}}
  {{- if .Values.recoveryDatabase.configMap.external }}
    {{- .Values.recoveryDatabase.configMap.name }}
  {{- else }}
    {{- include "chart.fullname" . }}-{{ .Values.recoveryDatabase.configMap.name }}
  {{- end }}
{{- end }}

{{/*
Database Secret Name
*/}}
{{- define "chart.recoveryDatabaseSecretName" -}}
  {{- if .Values.recoveryDatabase.secret.external }}
    {{- .Values.recoveryDatabase.secret.name }}
  {{- else }}
    {{- include "chart.fullname" . }}-{{ .Values.recoveryDatabase.secret.name }}
  {{- end }}
{{- end }}

{{/*
IAS Secret Name
*/}}
{{- define "chart.iasSecretName" -}}
  {{- if .Values.ias.secret.external }}
    {{- .Values.ias.secret.name }}
  {{- else }}
    {{- include "chart.fullname" . }}-{{ .Values.ias.secret.name }}
  {{- end }}
{{- end }}

{{/*
Sentry ConfigMap Name
*/}}
{{- define "chart.sentryConfigMapName" -}}
  {{- if .Values.sentry.configMap.external }}
    {{- .Values.sentry.configMap.name }}
  {{- else }}
    {{- include "chart.fullname" . }}-{{ .Values.sentry.configMap.name }}
  {{- end }}
{{- end }}

{{/*
supervisord-mobilecoind ConfigMap Name
*/}}
{{- define "chart.mobilecoindConfigMapName" -}}
  {{- if .Values.mobilecoind.configMap.external }}
    {{- .Values.mobilecoind.configMap.name }}
  {{- else }}
    {{- include "chart.fullname" . }}-{{ .Values.mobilecoind.configMap.name }}
  {{- end }}
{{- end }}

{{/*
Generate Peer List
*/}}
{{- define "chart.peerURLs" }}
  {{- $peerURLs := list }}
  {{- $name := include "chart.fullname" . }}
  {{- $namespace := .Release.Namespace }}
  {{- range $i, $e := until (int .Values.fogIngest.replicaCount ) }}
    {{- $peerURLs = append $peerURLs (printf "insecure-igp://%s-%d.%s.%s.svc.cluster.local:8090" $name $i $name $namespace) }}
  {{- end }}
  {{- join "," $peerURLs }}
{{- end }}

{{/*
mobilecoind quorum value
*/}}
{{- define "chart.mobilecoindQuorum" -}}
{ "threshold": {{ .Values.mobilecoind.quorumSetThreshold }}, "members": {{ include "chart.mobilecoindQuorumMembers" . }} }
{{- end }}

{{/*
Generate mobilecoind quorum value
*/}}
{{- define "chart.mobilecoindQuorumMembers" }}
  {{- $members := list }}
  {{- range .Values.mobilecoind.nodes }}
    {{- $members = append $members (dict "type" "Node" "args" .peer) }}
  {{- end }}
  {{- toJson $members }}
{{- end }}

{{/*
Mobilecoin Network (monitoring label)
*/}}
{{- define "chart.mobileCoinNetwork" -}}
  {{- if .Values.mobileCoinNetwork.configMap.external }}
    {{- (lookup "v1" "ConfigMap" .Release.Namespace .Values.mobileCoinNetwork.configMap.name).data.network | default "" }}
  {{- else }}
    {{- .Values.mobileCoinNetwork.value }}
  {{- end }}
{{- end }}

{{/*
fog-ingest ConfigMap Name
*/}}
{{- define "chart.fogIngestConfigMapName" -}}
  {{- if .Values.fogIngest.configMap.external }}
    {{- .Values.fogIngest.configMap.name }}
  {{- else }}
    {{- include "chart.fullname" . }}-{{ .Values.fogIngest.configMap.name }}
  {{- end }}
{{- end }}
