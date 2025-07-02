{{- define "ner-backend.name" -}}
ner-backend
{{- end -}}

{{- define "ner-backend.fullname" -}}
{{ .Release.Name }}-ner-backend
{{- end -}}