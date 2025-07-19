{{- define "flask-app.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "flask-app.name" -}}
{{- .Chart.Name -}}
{{- end -}}
