#!/bin/bash
#
# Génération de certificats SSL auto-signés pour développement
# Usage: ./generate_ssl.sh [domain]
#

set -e

DOMAIN="${1:-localhost}"
SSL_DIR="./nginx/ssl"
DAYS=365

echo "Génération de certificats SSL pour: ${DOMAIN}"

# Créer le dossier SSL s'il n'existe pas
mkdir -p "${SSL_DIR}"

# Générer une clé privée
echo "1. Génération de la clé privée..."
openssl genrsa -out "${SSL_DIR}/key.pem" 2048 2>/dev/null

# Générer un CSR (Certificate Signing Request)
echo "2. Création du CSR..."
openssl req -new -key "${SSL_DIR}/key.pem" -out "${SSL_DIR}/csr.pem" -subj "/C=TN/ST=Tunis/L=Tunis/O=Tunav IT Group/CN=${DOMAIN}" 2>/dev/null

# Générer le certificat auto-signé
echo "3. Création du certificat auto-signé..."
openssl x509 -req -in "${SSL_DIR}/csr.pem" -signkey "${SSL_DIR}/key.pem" -out "${SSL_DIR}/cert.pem" -days ${DAYS} -sha256 2>/dev/null

# Nettoyer le CSR intermédiaire
rm -f "${SSL_DIR}/csr.pem"

# Afficher les infos du certificat
echo ""
echo "Certificat généré:"
echo "  Domaine : ${DOMAIN}"
echo "  Valide pour : ${DAYS} jours"
echo "  Fichiers :"
echo "    - Certificat: ${SSL_DIR}/cert.pem"
echo "    - Clé privée: ${SSL_DIR}/key.pem"
echo ""
echo "Test:"
echo "  openssl x509 -in ${SSL_DIR}/cert.pem -noout -text | grep -A2 'Subject:"
echo ""
echo "⚠️  Attention: Ce certificat est auto-signé. Pour la production, utilisez Let's Encrypt ou un CA reconnu."
