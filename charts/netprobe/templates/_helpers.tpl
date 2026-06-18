{{/*
Chart name, trimmed to 63 chars.
*/}}
{{- define "netprobe.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Full name: release + chart, trimmed to 63 chars.
*/}}
{{- define "netprobe.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Chart label value: name-version, used in helm.sh/chart annotation.
*/}}
{{- define "netprobe.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Pod name: Values.pod.name if set, otherwise the Helm release name.
*/}}
{{- define "netprobe.podName" -}}
{{- .Values.pod.name | default .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels — stable across upgrades (no chart version).
IMPORTANT: these are the only labels used in matchLabels and pod template selectors.
Adding version-bearing labels here would make DaemonSet upgrades impossible.
*/}}
{{- define "netprobe.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netprobe.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Full set of labels applied to resource metadata.
Includes the chart version and managed-by fields on top of selectorLabels.
Do NOT use these in matchLabels or pod template selectors.
*/}}
{{- define "netprobe.labels" -}}
helm.sh/chart: {{ include "netprobe.chart" . }}
{{ include "netprobe.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Build the full image reference. Digest takes priority over tag for immutability.
Handles empty registry gracefully (bare repository name).
*/}}
{{- define "netprobe.image" -}}
{{- $ref := .Values.image.repository -}}
{{- if .Values.image.registry -}}
{{- $ref = printf "%s/%s" .Values.image.registry .Values.image.repository -}}
{{- end -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" $ref .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $ref .Values.image.tag -}}
{{- end -}}
{{- end }}

{{/*
tcpdump command for pod mode.
Writes rotating .pcap files named with a timestamp.
*/}}
{{- define "netprobe.tcpdump.cmd" -}}
{{- $filter := "" -}}
{{- if .Values.tcpdump.filterHost -}}
  {{- $filter = printf " host %s" .Values.tcpdump.filterHost -}}
{{- end -}}
{{- if .Values.tcpdump.verbose -}}
tcpdump -i {{ .Values.tcpdump.interface }} -n{{ $filter }}
{{- else -}}
tcpdump -i {{ .Values.tcpdump.interface }} -n{{ $filter }} -G {{ .Values.tcpdump.rotateSeconds }} -w {{ .Values.tcpdump.outputDir }}/{{ .Values.tcpdump.filePrefix }}-%Y-%m-%d_%H-%M-%S.pcap
{{- end -}}
{{- end }}

{{/*
tcpdump command for DaemonSet mode.
Injects $(hostname) into the filename so pods on different nodes never collide on the share.
The command is run via /bin/bash -c so $(hostname) is expanded at container start.
*/}}
{{- define "netprobe.tcpdump.cmd.ds" -}}
{{- $filter := "" -}}
{{- if .Values.tcpdump.filterHost -}}
  {{- $filter = printf " host %s" .Values.tcpdump.filterHost -}}
{{- end -}}
{{- if .Values.tcpdump.verbose -}}
tcpdump -i {{ .Values.tcpdump.interface }} -n{{ $filter }}
{{- else -}}
tcpdump -i {{ .Values.tcpdump.interface }} -n{{ $filter }} -G {{ .Values.tcpdump.rotateSeconds }} -w {{ .Values.tcpdump.outputDir }}/{{ .Values.tcpdump.filePrefix }}-$(hostname)-%Y-%m-%d_%H-%M-%S.pcap
{{- end -}}
{{- end }}
