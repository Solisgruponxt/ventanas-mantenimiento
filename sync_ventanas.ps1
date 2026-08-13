$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$projectDir = 'C:\Users\jsolis\Documents\Claude\Ventanas'
Set-Location $projectDir

$prompt = @'
Sincroniza el dashboard de "ventanas de mantenimiento a servidores" con los correos nuevos de Gmail (cuenta jsolis@nxtview.com, ya conectada via MCP). Este es un directorio local que tambien es un repo de git con remote a github.com/Solisgruponxt/ventanas-mantenimiento (rama main), publicado con GitHub Pages.

ARCHIVOS EN ESTE DIRECTORIO:
- ventanas_final.json: dataset canonico, array de eventos con campos {titulo, thread_ids (array de ids de Gmail), fecha (YYYY-MM-DD), hora_inicio, hora_fin, timezone, sistema_o_proyecto (texto libre), sistema_tag (categoria normalizada), estado (confirmada|tentativa|pendiente|cancelada|desconocido), notas}.
- ventanas_data.json: version "slim" del mismo dataset con claves abreviadas {f,hi,hf,tz,sis,det,est,tit,not} = {fecha,hora_inicio,hora_fin,timezone,sistema_tag,sistema_o_proyecto,estado,titulo,notas}. ARCHIVO DERIVADO, se regenera desde ventanas_final.json, nunca se edita a mano.
- dashboard_template.html: plantilla del dashboard con el marcador literal __VENTANAS_DATA__ en vez del JSON embebido.
- index.html y Mapa_Ventanas.html: el dashboard final (identicos), se generan reemplazando __VENTANAS_DATA__ en dashboard_template.html con el contenido de ventanas_data.json. ARCHIVOS DERIVADOS.
- sync_state.json: marcador de estado, campo "last_event_fecha" = fecha maxima ya procesada.

PASO 1 - Leer estado: Lee sync_state.json para obtener last_event_fecha. Lee ventanas_final.json y arma un set con TODOS los thread_ids ya existentes (para no reprocesar correos ya conocidos).

PASO 2 - Buscar correos nuevos: Usa la herramienta MCP de Gmail (search_threads) contra la cuenta jsolis@nxtview.com con variaciones de query como "subject:ventana", "ventana mantenimiento servidor", "mantenimiento servidor", restringido con "newer_than:35d" (margen suficiente para reagendamientos). Excluye cualquier thread_id que ya este en el set de conocidos del paso 1.

PASO 3 - Clasificar y extraer cada correo nuevo:
- Dos tipos: (a) invitaciones de calendario, fecha/hora en el asunto o en linea "Cuando:"/"When:" del cuerpo; (b) correos reenviados/manuales sin fecha en el asunto, requieren abrir el cuerpo con get_thread.
- Correos de RSVP en espanol sobre la MISMA invitacion ("Aceptado:", "Aceptada:", "Aceptado tentativamente:", "Cancelado:", "Rechazada:") son EL MISMO evento - agrupar por asunto normalizado (sin prefijo RSVP) + fecha.
- Estado: "Cancelado" presente -> cancelada; aceptacion firme -> confirmada; solo "tentativamente" -> tentativa; solicitud sin respuesta -> pendiente; no determinable -> desconocido.
- Descarta correos que NO sean una ventana de mantenimiento real (OOO automaticos, invitaciones de otro tema, reportes sin fecha determinable). No agregarlos.
- sistema_tag (primera regla que haga match, si ninguna -> "Otros"): A3T -> /\bA3T\b|ABEN\s*3T|ABENT\s*3T|ABEN3T|ABNT/i ; ABT -> /\bABT\b/i ; "EIN / PE Ingenio" -> /\bEIN\b|PE\s*Ingenio|Ingenio/i ; EDF -> /\bEDF\b/i ; "ERT / El Retiro" -> /\bERT\b|El\s*Retiro|Retiro/i ; DEMEX -> /DEMEX|Demex/ ; "DEM / DED" -> /DEM.*DED|DED.*DEM|DEM,\s*DED|DEM y DED/i ; "BII Hioxo" -> /BII\s*Hioxo|Hioxo/i ; "EGU / Eolica del Golfo" -> /\bEGU\b|Eolica del Golfo/i ; "SSS / Salsipuedes" -> /\bSSS\b|Salsipuedes/i ; TRE -> /\bTRE\b/i ; TRW -> /\bTRW\b/i ; "San Matias" -> /San\s*Matias/i ; BRIO -> /\bBRIO\b/i ; EDP -> /\bEDP\b/i ; "SIGMA / VPN CFE" -> /\bSIGMA\b/i ; Naturgy -> /Naturgy/i ; ETM -> /\bETM/i ; "AT&T / Energias Limpias" -> /AT&T|Energias Limpias/i ; Bimbo -> /Bimbo/i.

PASO 4 - Consolidar duplicados: entre eventos NUEVOS (y comparando contra existentes en ventanas_final.json), si comparten fecha + sistema_tag, es el mismo evento (solicitud + confirmacion + reporte posterior) - fusionar: conservar el mas completo, "cancelada" siempre gana, "confirmada" gana sobre tentativa/pendiente/desconocido; unir thread_ids; anotar "[Consolidado de N correos]" en notas.

PASO 5 - Actualizar archivos: agregar eventos nuevos consolidados a ventanas_final.json (append, sin reescribir existentes salvo fusion). Regenerar ventanas_data.json completo desde ventanas_final.json. Regenerar index.html y Mapa_Ventanas.html reemplazando __VENTANAS_DATA__ en dashboard_template.html con el contenido de ventanas_data.json (usar un script, no pegar el JSON a mano). Actualizar sync_state.json con el nuevo last_event_fecha.

PASO 6 - Commit y push: SOLO si se agregaron eventos nuevos, hacer "git add", commit con mensaje "Sync automatico: +N ventana(s) nueva(s) (fecha de hoy)" indicando sistemas involucrados, y "git push". Si no hay eventos nuevos, NO hacer commit y terminar sin mas acciones.

Se conservador: ante ambiguedad de si un correo es o no una ventana real, prefiere no agregarlo antes que ensuciar el dataset.
'@

$allowedTools = @(
  'Bash(git *)',
  'Bash(python3 *)',
  'Read', 'Write', 'Edit', 'Glob', 'Grep',
  'mcp__claude_ai_Gmail__search_threads',
  'mcp__claude_ai_Gmail__get_thread',
  'mcp__claude_ai_Gmail__list_labels'
)

$logFile = Join-Path $projectDir 'sync_log.txt'
"`n===== Sync run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') =====" | Out-File -FilePath $logFile -Append -Encoding utf8

$prompt | & claude -p --permission-mode bypassPermissions --allowedTools $allowedTools --add-dir $projectDir *>&1 |
  Out-File -FilePath $logFile -Append -Encoding utf8
