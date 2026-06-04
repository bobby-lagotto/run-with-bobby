#!/bin/bash

# Script di build per Run with Bobby
# Automatizza la compilazione e configurazione del progetto

echo "🏃‍♂️ Run with Bobby - Build Script"
echo "=================================="

# Verifica che Xcode sia installato
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Errore: Xcode non trovato. Installa Xcode dalle App Store."
    exit 1
fi

# Verifica versione minima di Xcode (15.0+)
XCODE_VERSION=$(xcodebuild -version | head -n1 | cut -d ' ' -f2)
echo "📱 Versione Xcode: $XCODE_VERSION"

# Security preflight
echo "🔐 Scansione segreti..."
scripts/scan-secrets.sh

# Pulisci build precedenti
echo "🧹 Pulizia build precedenti..."
xcodebuild clean -project RunWithBobby.xcodeproj -scheme RunWithBobby

# Verifica dipendenze MLX
echo "🔍 Verifica dipendenze MLX Swift..."
if [ ! -d "Packages" ]; then
    echo "📦 Download dipendenze MLX Swift..."
    xcodebuild -resolvePackageDependencies -project RunWithBobby.xcodeproj
fi

# Build per device (Release)
echo "🔨 Build per dispositivo (Release)..."
xcodebuild build -project RunWithBobby.xcodeproj \
    -scheme RunWithBobby \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -allowProvisioningUpdates

if [ $? -eq 0 ]; then
    echo "✅ Build completato con successo!"
    echo ""
    echo "📋 Prossimi passi:"
    echo "1. Apri RunWithBobby.xcodeproj in Xcode"
    echo "2. Configura il tuo Team ID nelle impostazioni di Signing"
    echo "3. Connetti un iPhone fisico (MLX richiede hardware reale)"
    echo "4. Premi Run per installare l'app"
    echo ""
    echo "🎯 L'app richiede almeno iOS 16.0+ e 3GB di RAM per prestazioni ottimali"
    
else
    echo "❌ Errore durante il build. Controlla i log sopra."
    echo ""
    echo "🛠 Possibili soluzioni:"
    echo "1. Verifica che tutte le dipendenze siano installate"
    echo "2. Controlla la configurazione del Team ID"
    echo "3. Assicurati di avere Xcode 15.0 o superiore"
    exit 1
fi

echo ""
echo "🏃‍♂️ Buona corsa con Bobby! 💨"