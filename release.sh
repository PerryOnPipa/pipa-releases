#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
#                          CONFIGURAZIONE OBBLIGATORIA
# ==============================================================================
DEVICE="pipa"  # <-- Non modificare questo nome (deve matchare lo ZIP)
ROM_DIR="../out/target/product/${DEVICE}"
ZIP_PATTERN="*-COMMUNITY-GMS-${DEVICE}.zip"

# ==============================================================================
#                          FUNZIONI DI UTILITÀ
# ==============================================================================
panic() {
    echo -e "\033[1;31mERRORE:\033[0m $1"
    exit 1
}

check_prerequisites() {
    # Verifica esistenza directory ROM
    [[ ! -d "$ROM_DIR" ]] && panic "Directory ROM non trovata: ${ROM_DIR}"

    # Verifica presenza file obbligatori
    local required_files=(
        "${ROM_DIR}/boot.img"
        "${ROM_DIR}/dtbo.img"
        "${ROM_DIR}/vendor_boot.img"
    )

    for f in "${required_files[@]}"; do
        [[ ! -f "$f" ]] && panic "File mancante: ${f##*/}"
    done
}

# ==============================================================================
#                          LOGICA PRINCIPALE
# ==============================================================================
echo -e "\n\033[1;36m[${DEVICE} Release Manager]\033[0m"

# Step 1: Verifica preliminari
check_prerequisites

# Step 2: Identifica ZIP della ROM
zip_files=("${ROM_DIR}"/${ZIP_PATTERN})
case ${#zip_files[@]} in
    0)  panic "Nessuno ZIP trovato con pattern: ${ZIP_PATTERN}
        Esempio atteso: axion-1.1-20240309-COMMUNITY-GMS-${DEVICE}.zip" ;;
    1)  zip_path="${zip_files[0]}" ;;
    *)  panic "Trovati ${#zip_files[@]} ZIP compatibili. Mantenere solo lo ZIP principale" ;;
esac

# Step 3: Estrai metadati
zip_name=$(basename "$zip_path")
tag=$(basename "$zip_path" .zip | sed -E 's/(.*)-[0-9]{8}-.*/\1/')
title="${zip_name%-COMMUNITY-GMS-*} [$(date +'%Y-%m-%d')]"

echo -e "\n\033[1;32mTrovato ZIP:\033[0m ${zip_name}"
echo -e "\033[1;36mRelease Tag:\033[0m ${tag}"
echo -e "\033[1;36mRelease Title:\033[0m ${title}"

# Step 4: Copia file temporanei
echo -e "\n\033[1;33mPreparazione file...\033[0m"
tmp_dir=$(mktemp -d)
cp -v "${ROM_DIR}/boot.img" "$tmp_dir"
cp -v "${ROM_DIR}/dtbo.img" "$tmp_dir"
cp -v "${ROM_DIR}/vendor_boot.img" "$tmp_dir"
cp -v "$zip_path" "$tmp_dir"

# Step 5: Raccolta note di release
echo -e "\n\033[1;35mInserisci le note di release (max 5):\033[0m"
notes=()
for i in {1..5}; do
    read -r -p "Note ${i} (invio per saltare): " note
    [[ -z "$note" ]] && break
    notes+=("- ${note}")
done

# Step 6: Costruzione comando
release_files=(
    "${tmp_dir}/boot.img"
    "${tmp_dir}/dtbo.img"
    "${tmp_dir}/vendor_boot.img"
    "${tmp_dir}/${zip_name}"
)

echo -e "\n\033[1;34mComando finale:\033[0m"
echo "gh release create \"${tag}\" \\"
printf "  %s \\ \n" "${release_files[@]}"
echo "  --title \"${title}\" \\"
echo "  --notes \"$(printf '%s\n' "${notes[@]}")\""

# Step 7: Conferma
read -r -p "Confermare l'esecuzione? (y/N) " response
if [[ "$response" =~ ^[Yy]$ ]]; then
    gh release create "${tag}" "${release_files[@]}" \
        --title "${title}" \
        --notes "$(printf '%s\n' "${notes[@]}")"
    echo -e "\n\033[1;32mRelease creata con successo!\033[0m"
else
    echo -e "\n\033[1;33mOperazione annullata\033[0m"
fi

# Step 8: Pulizia
echo -e "\nPulizia file temporanei..."
rm -rf "$tmp_dir"
