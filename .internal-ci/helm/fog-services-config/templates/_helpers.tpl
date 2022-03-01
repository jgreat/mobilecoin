{{/* Expand the name of the fogServicesConfig. */}}
{{- define "fogServicesConfig.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fogServicesConfig.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- tpl .Values.fullnameOverride . | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "fogServicesConfig.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels */}}
{{- define "fogServicesConfig.labels" -}}
helm.sh/chart: {{ include "fogServicesConfig.chart" . }}
{{ include "fogServicesConfig.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels */}}
{{- define "fogServicesConfig.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fogServicesConfig.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* pgPassword - reuse existing password */}}
{{- define "fogServicesConfig.pgPassword" -}}
{{- $pgPassword := randAlphaNum 48 }}
{{- if .Values.fogRecoveryDatabaseReader.password }}
{{- $pgPassword = .Values.fogRecoveryDatabaseReader.password }}
{{- end }}
{{- $pgSecret := (lookup "v1" "Secret" .Release.Namespace "fog-recovery-postgresql") }}
{{- if $pgSecret }}
{{- $pgPassword = index $pgSecret.data "postgres-password" | b64dec }}
{{- end }}
{{- $pgPassword }}
{{- end }}

{{/* pgReplicationPassword - reuse existing password */}}
{{- define "fogServicesConfig.pgReplicationPassword" -}}
{{- $pgReplicationPassword := randAlphaNum 48 }}
{{- $pgSecret := (lookup "v1" "Secret" .Release.Namespace "fog-recovery-postgresql") }}
{{- if $pgSecret }}
{{- $pgReplicationPassword = index $pgSecret.data "replication-password" | b64dec }}
{{- end }}
{{- $pgReplicationPassword }}
{{- end }}

{{/* fogViewCookieSalt - reuse existing password */}}
{{- define "fogServicesConfig.fogViewCookieSalt" -}}
{{- $salt := randAlphaNum 8 }}
{{- if .Values.fogView.cookie.salt }}
{{- $salt = .Values.fogView.cookie.salt }}
{{- end }}
{{- $saltSecret := (lookup "v1" "Secret" .Release.Namespace "fog-view-cookie") }}
{{- if $saltSecret }}
{{- $salt = index $saltSecret.data "salt" | b64dec }}
{{- end }}
{{- $salt }}
{{- end }}

{{/* fogLedgerCookieSalt - reuse existing password */}}
{{- define "fogServicesConfig.fogLedgerCookieSalt" -}}
{{- $salt := randAlphaNum 8 }}
{{- if .Values.fogLedger.cookie.salt }}
{{- $salt = .Values.fogLedger.cookie.salt }}
{{- end }}
{{- $saltSecret := (lookup "v1" "Secret" .Release.Namespace "fog-ledger-cookie") }}
{{- if $saltSecret }}
{{- $salt = index $saltSecret.data "salt" | b64dec }}
{{- end }}
{{- $salt }}
{{- end }}
