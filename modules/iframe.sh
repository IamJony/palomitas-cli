#!/bin/bash
# iframe.sh - Reproductores server1
# Uso: ./iframe.sh <URL DE LA PELICULA>

source "$(dirname "$0")/config.sh" --server1

if [ $# -eq 0 ]; then
    echo "Uso: $0 <URL DE LA PELICULA>"
    exit 1
fi

URL_PELICULA="$1"

init_session

log_info "Obteniendo reproductores en $SERVER..."

wget -q --no-check-certificate -U "$USER_AGENT" --load-cookies="$COOKIE_FILE" -O "$TEMP_HTML" "$URL_PELICULA"

if [ $? -ne 0 ] || [ ! -s "$TEMP_HTML" ]; then
    log_error "Error al descargar la página"
    cleanup
    exit 1
fi

POST_ID=$(grep "shortlink" "$TEMP_HTML" | grep -o "?p=[0-9]\+" | head -1 | sed 's/?p=//')

if [ -z "$POST_ID" ]; then
    log_error "No se pudo extraer el ID de la película"
    cleanup
    exit 1
fi

log_success "ID encontrado: $POST_ID"

RESPONSE=$(wget -q --no-check-certificate -O - \
    --header="X-Requested-With: XMLHttpRequest" \
    --header="Referer: $URL_PELICULA" \
    --header="User-Agent: $USER_AGENT" \
    --post-data="action=doo_player_ajax&post=$POST_ID&nume=1&type=movie" \
    "$AJAX_URL")

if [ -z "$RESPONSE" ]; then
    log_error "Error al consultar la API"
    cleanup
    exit 1
fi

# Guardar respuesta cruda (estándar)
echo "$RESPONSE" > "$TEMP_DIR/player_${POST_ID}.json"

# Extraer EMBED_URL sin escapes (JSON válido)
EMBED_URL=$(echo "$RESPONSE" | grep -o 'src=\\*"[^"]*\\*"' | head -1 | sed 's/src=\\*"//;s/\\*"//')
[ -z "$EMBED_URL" ] && EMBED_URL=$(echo "$RESPONSE" | grep -o "src='[^']*'" | head -1 | sed "s/src='//;s/'//")

# Desescapar \/ → /
EMBED_URL=$(echo "$EMBED_URL" | sed 's|\\/|/|g')

if [ -z "$EMBED_URL" ]; then
    log_error "No se detectó 'embed_url'"
    cleanup
    exit 1
fi

# Escribir peli.json con jq (JSON válido)
jq -n --arg url "$EMBED_URL" '{embed_url: $url, url: $url}' > "$TEMP_DIR/peli.json"
log_success "Player encontrado"

cleanup
