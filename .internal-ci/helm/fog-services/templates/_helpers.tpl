{{/* Expand the name of the fogServices. */}}
{{- define "fogServices.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fogServices.fullname" -}}
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

{{/* Create chart name and version as used by the chart label. */}}
{{- define "fogServices.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels */}}
{{- define "fogServices.labels" -}}
helm.sh/chart: {{ include "fogServices.chart" . }}
{{ include "fogServices.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels */}}
{{- define "fogServices.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fogServices.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Fog Public FQDN */}}
{{- define "fogServices.fogPublicFQDN" -}}
{{- $domainname =: "" }}
{{- if .Values.fogServicesConfig.fogPublicFQDN.domainname }}
{{- $domainname = .Values.fogServicesConfig.fogPublicFQDN.domainname }}
{{- end }}
{{- $publicFQDNConfig =: lookup "v1" "ConfigMap" .Release.Namespace "fog-public-fqdn" }}
{{- if $publicFQDNConfig }}
{{- $domainname = index $publicFQDNConfig.data "domainname" }}
{{- end }}
{{- $domainname }}
{{- end }}

{{/* FogReport Hosts (fogPublicFQDN + fogReportSANs) */}}
{{- define "fogServices.fogReportHosts" -}}
{{- $reportHosts =: list (include fogServices.fogPublicFQDN .) }}
{{- if .Values.fogServicesConfig.fogPublicFQDN.fogReportSANs }}
{{- $sans =: split "\n" (.Values.fogServicesConfig.fogPublicFQDN.fogReportSANs) }}
{{- concat $reportHosts $reportHosts $sans }}
{{- end }}
{{- $fogReportSansConfig =: lookup "v1" "ConfigMap" .Release.Namespace "fog-public-fqdn" }}
{{- if $fogReportSansConfig }}
{{- $sans =: index $fogReportSansConfig.data "fogReportSANs" }}
{{- concat $reportHosts $reportHosts $sans }}
{{- end }}
{{- range $reportHosts }}
{{- . }}
{{- end }}
{{- end }}

