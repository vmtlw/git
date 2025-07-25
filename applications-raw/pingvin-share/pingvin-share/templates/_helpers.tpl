{{- define "pingvin-share.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "pingvin-share.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end }}

{{- define "pingvin-share.labels" -}}
app.kubernetes.io/name: {{ include "pingvin-share.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

