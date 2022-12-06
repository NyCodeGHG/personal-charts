{{/*
Expand the name of the chart.
*/}}
{{- define "miniflux.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "miniflux.fullname" -}}
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
{{- define "miniflux.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "miniflux.labels" -}}
helm.sh/chart: {{ include "miniflux.chart" . }}
{{ include "miniflux.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "miniflux.selectorLabels" -}}
app.kubernetes.io/name: {{ include "miniflux.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "miniflux.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "miniflux.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the Image string to use
*/}}
{{- define "miniflux.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/*
Determine admin secret name
*/}}
{{- define "miniflux.admin-secret" -}}
{{- .Values.auth.existingSecret | default (printf "%s-admin-secret" (include "miniflux.fullname" .)) }}
{{- end }}

{{/*
Determine username secret key
*/}}
{{- define "miniflux.admin-secret-username-key" -}}
{{- .Values.auth.secretKeys.username | default "username" }}
{{- end }}

{{/*
Determine password secret key
*/}}
{{- define "miniflux.admin-secret-password-key" -}}
{{- .Values.auth.secretKeys.password | default "password" }}
{{- end }}

{{/*
Determine oauth secret name
*/}}
{{- define "miniflux.oauth-secret" -}}
{{- .Values.auth.oauth2.existingSecret | default (printf "%s-oauth-secret" (include "miniflux.fullname" .)) }}
{{- end }}

{{/*
Determine oauth client-secret secret key
*/}}
{{- define "miniflux.oauth-secret-client-secret-key" -}}
{{- .Values.auth.oauth2.secretKeys.clientSecret | default (printf "clientSecret") }}
{{- end }}

{{/*
Determine oauth client-id secret key
*/}}
{{- define "miniflux.oauth-secret-client-id-key" -}}
{{- .Values.auth.oauth2.secretKeys.clientId | default (printf "clientId") }}
{{- end }}

{{/*
Postgres Connection URL
*/}}
{{- define "miniflux.postgresql.connection-url" -}}
{{- $postgresHost := include "postgresql.primary.fullname" .Subcharts.postgresql }}
{{- $postgresUsername := include "postgresql.username" .Subcharts.postgresql }}
{{- $postgresPort := include "postgresql.service.port" .Subcharts.postgresql }}
{{- $postgresDatabase := include "postgresql.database" .Subcharts.postgresql }}
{{- printf "postgres://%s:%s@%s:%s/%s?sslmode=disable" $postgresUsername "$(POSTGRES_PASSWORD)" $postgresHost $postgresPort $postgresDatabase }}
{{- end }}

{{/*
Wait for Postgres init-container
*/}}
{{- define "miniflux.postgresql.wait-init-container" -}}
{{- $customUser := include "postgresql.username" .Subcharts.postgresql }}
{{- $postgresHost := include "postgresql.primary.fullname" .Subcharts.postgresql }}
- name: wait-for-postgres
  image: {{ include "postgresql.image" .Subcharts.postgresql }}
  command:
    - "/bin/sh"
    - "-c"
  {{- if (include "postgresql.database" .Subcharts.postgresql) }}
    - |
        until pg_isready -U {{ $customUser | default "postgres" | quote }} -d "dbname={{ include "postgresql.database" .Subcharts.postgresql }} {{- if and .Values.postgresql.tls.enabled .Values.postgresql.tls.certCAFilename }} sslcert={{ include "postgresql.tlsCert" .Subcharts.postgresql }} sslkey={{ include "postgresql.tlsCertKey" . }}{{- end }}" -h {{ $postgresHost }} -p {{ template "postgresql.service.port" .Subcharts.postgresql }}
        do
          sleep 2;
        done
  {{- else }}
    - |
        until pg_isready -U {{ $customUser | default "postgres" | quote }} {{- if and .Values.postgresql.tls.enabled .Values.postgresql.tls.certCAFilename }} -d "sslcert={{ include "postgresql.tlsCert" .Subcharts.postgresql }} sslkey={{ include "postgresql.tlsCertKey" .Subcharts.postgresql }}"{{- end }} -h {{ $postgresHost }} -p {{ template "postgresql.service.port" .Subcharts.postgresql }}
        do
          sleep 2;
        done
  {{- end }}
{{- end }}

{{/*
Determine ConfigMap name
*/}}
{{- define "miniflux.configmap" -}}
{{ printf "%s-oauth" (include "miniflux.fullname" .) }}
{{- end }}

{{/*
Determine Base URL.
*/}}
{{- define "miniflux.baseUrl" -}}
{{ .Values.baseUrl | default .Values.ingressRoute.host }}
{{- end }}
