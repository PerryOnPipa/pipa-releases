#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
#                          CONFIGURAZIONE OBBLIGATORIA
# ==============================================================================
DEVICE="pipa"                             # <--- MODIFICARE QUESTA VARIABILE
ROM_DIR="../out/target/product/${DEVICE}" # Path relativo alla directory dello script
ZIP_PATTERN="*-COMMUNITY-GMS-${DEVICE}.zip"

# ==============================================================================
#                          FUNZIONI DI UTILITÀ (NON MODIFICARE)
# ==============================================================================
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

panic() {
    echo -e "\n${RED}[ERRORE CRITICO]${NC}"
    echo -e "• $1"
    echo -e "• Path verificato: ${CYAN}$(realpath "$ROM_DIR" 2>/dev/null || echo "non trovato")${NC}\n"
    exit 1
}

cleanup() {
    if [[ -d "$tmp_dir" ]]; then
        echo -e "\n${YELLOW}Pulizia file temporanei...${NC}"
        #rm -rf "$tmp_dir"
    fi
}

# ==============================================================================
#                          LOGICA PRINCIPALE
# ==============================================================================
trap cleanup EXIT INT TERM

# Creazione directory temporanea
tmp_dir=".release_temp_${DEVICE}_$(date +%s)"
mkdir -p "$tmp_dir" || panic "Impossibile creare directory temporanea"

echo -e "\n${CYAN}[${DEVICE} Release Manager]${NC}"
echo -e "• Data: $(date)"
echo -e "• Directory lavoro: ${CYAN}$(pwd)${NC}"
echo -e "• Temp dir: ${CYAN}${tmp_dir}${NC}"

# ==============================================================================
#                          VERIFICA PRELIMINARE
# ==============================================================================
echo -e "\n${GREEN}Verifica prerequisiti...${NC}"

# Verifica directory ROM
[[ ! -d "$ROM_DIR" ]] && panic "Directory ROM non trovata"

# Verifica file obbligatori
declare -a required_files=(
    "${ROM_DIR}/boot.img"
    "${ROM_DIR}/dtbo.img"
    "${ROM_DIR}/vendor_boot.img"
)

for f in "${required_files[@]}"; do
    [[ ! -f "$f" ]] && panic "File mancante: ${f##*/}"
    [[ ! -s "$f" ]] && panic "File vuoto/corrotto: ${f##*/}"
done

# Verifica ZIP
zip_files=("${ROM_DIR}"/${ZIP_PATTERN})
case ${#zip_files[@]} in
    0)  panic "Nessuno ZIP trovato con pattern: ${ZIP_PATTERN}\nEsempio atteso: rom-name-1.0-20240315-COMMUNITY-GMS-${DEVICE}.zip" ;;
    1)  zip_path="${zip_files[0]}" ;;
    *)  panic "Trovati ${#zip_files[@]} ZIP compatibili. Mantenere solo lo ZIP principale" ;;
esac

# ==============================================================================
#                          PREPARAZIONE FILE
# ==============================================================================
echo -e "\n${GREEN}Trovato ZIP: ${CYAN}$(basename "$zip_path")${NC}"

# Estrai metadati
zip_name=$(basename "$zip_path")
tag=$(basename "$zip_path" .zip | sed -E 's/(.*)-[0-9]{8}-.*/\1/')
title="${zip_name%-COMMUNITY-GMS-*} [$(date +'%Y-%m-%d')]"

echo -e "• ${CYAN}Release Tag:${NC} ${tag}"
echo -e "• ${CYAN}Titolo Release:${NC} ${title}"

# Copia file
echo -e "\n${YELLOW}Copio file in ${tmp_dir}...${NC}"
cp -v "${ROM_DIR}/boot.img" "$tmp_dir"
cp -v "${ROM_DIR}/dtbo.img" "$tmp_dir"
cp -v "${ROM_DIR}/vendor_boot.img" "$tmp_dir"
cp -v "$zip_path" "$tmp_dir"

# ==============================================================================
#                          NOTE DI RELEASE
# ==============================================================================
echo -e "\n${CYAN}Inserisci le note di release (max 5):${NC}"
notes=()
for i in {1..5}; do
    read -r -p "Note ${i} (invio per terminare): " note
    [[ -z "$note" ]] && break
    notes+=("- ${note}")
done

# ==============================================================================
#                          COSTRUZIONE COMANDO
# ==============================================================================
release_files=(
    "${tmp_dir}/boot.img"
    "${tmp_dir}/dtbo.img"
    "${tmp_dir}/vendor_boot.img"
    "${tmp_dir}/${zip_name}"
)

echo -e "\n${CYAN}COMANDO FINALE:${NC}"
echo "gh release create \"${tag}\" \\"
printf "  %s \\\n" "${release_files[@]}"
echo "  --title \"${title}\" \\"
echo "  --notes \"$(printf '%s\n' "${notes[@]}")\""

# ==============================================================================
#                          CONFERMA ED ESECUZIONE
# ==============================================================================
read -r -p $'\n'"${YELLOW}Confermare l'esecuzione? (y/N): ${NC}" response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo -e "\n${GREEN}Creazione release in corso...${NC}"
    gh release create "${tag}" "${release_files[@]}" \
        --title "${title}" \
        --notes "$(printf '%s\n' "${notes[@]}")"
    echo -e "\n${GREEN}✓ Release creata con successo!${NC}"
else
    echo -e "\n${YELLOW}✗ Operazione annullata${NC}"
fi
