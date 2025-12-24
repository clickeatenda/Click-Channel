# 🚀 Guia de Deploy - Click Channel

## Issue no GitHub
**Issue #134:** [Compilação APK e Instalação no Firestick e Tablet](https://github.com/clickeatenda/Click-Channel/issues/134)

---

## 📱 Dispositivos Configurados

| Dispositivo | IP | Status |
|-------------|-------|--------|
| **Fire TV Stick** | 192.168.3.110 | ⏳ |
| **Tablet** | 192.168.3.159 | ⏳ |

---

## 🚀 Uso Rápido

### Opção 1: Script Automático (Recomendado)

#### Windows (PowerShell)
```powershell
# Executar script de deploy
./deploy.ps1
```

#### Linux/Mac (Bash)
```bash
# Tornar executável
chmod +x deploy.sh

# Executar
./deploy.sh
```

O script fará automaticamente:
1. ✅ Compilar APK Release
2. ✅ Conectar aos dois dispositivos
3. ✅ Instalar no Fire Stick
4. ✅ Instalar no Tablet
5. ✅ Mostrar resumo

---

### Opção 2: Comandos Manuais

#### 1. Compilar APK
```bash
flutter build apk --release
```

#### 2. Conectar Dispositivos
```bash
# Fire Stick
adb connect 192.168.3.110:5555

# Tablet
adb connect 192.168.3.159:5555

# Verificar conexão
adb devices
```

#### 3. Instalar nos Dispositivos
```bash
# Fire Stick
adb -s 192.168.3.110:5555 install -r build/app/outputs/flutter-apk/app-release.apk

# Tablet
adb -s 192.168.3.159:5555 install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔧 Preparação dos Dispositivos (Primeira Vez)

### Fire TV Stick

1. **Habilitar Opções do Desenvolvedor:**
   - Ir para **Configurações** > **Minha Fire TV**
   - Selecionar **Sobre** > **Tocar 7x no nome do dispositivo**

2. **Habilitar ADB:**
   - **Configurações** > **Minha Fire TV** > **Opções do Desenvolvedor**
   - Ativar **Depuração ADB**
   - Ativar **Apps de Fontes Desconhecidas**

3. **Anotar o IP:**
   - **Configurações** > **Minha Fire TV** > **Sobre** > **Rede**
   - IP: `192.168.3.110`

### Tablet

1. **Habilitar Modo Desenvolvedor:**
   - **Configurações** > **Sobre o Tablet**
   - Tocar 7 vezes em **Número da Compilação**

2. **Habilitar Depuração:**
   - Voltar para **Configurações**
   - Entrar em **Opções do Desenvolvedor**
   - Ativar **Depuração USB**
   - Ativar **Depuração por rede** (se disponível)

3. **Anotar o IP:**
   - **Configurações** > **Sobre** > **Wi-Fi**
   - IP: `192.168.3.159`

---

## 🐛 Soluções de Problemas

### Dispositivo não conecta

```bash
# Verificar se está na mesma rede
ping 192.168.3.110
ping 192.168.3.159

# Tentar reconectar
adb disconnect
adb connect 192.168.3.110:5555
adb connect 192.168.3.159:5555
```

### "device offline"

```bash
# Reiniciar servidor ADB
adb kill-server
adb start-server

# Reconectar
adb connect 192.168.3.110:5555
```

### "device unauthorized"

1. No dispositivo, aparecerá uma mensagem perguntando se autoriza o computador
2. Marcar "Sempre permitir" e aceitar
3. Reconectar via ADB

### APK não instala

```bash
# Desinstalar versão antiga
adb -s 192.168.3.110:5555 uninstall com.clickeatenda.clickchannel

# Instalar novamente
adb -s 192.168.3.110:5555 install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 📊 Comandos Úteis

### Ver logs do app
```bash
# Fire Stick
adb -s 192.168.3.110:5555 logcat | grep -i flutter

# Tablet
adb -s 192.168.3.159:5555 logcat | grep -i flutter
```

### Iniciar o app remotamente
```bash
# Fire Stick
adb -s 192.168.3.110:5555 shell monkey -p com.clickeatenda.clickchannel -c android.intent.category.LAUNCHER 1

# Tablet
adb -s 192.168.3.159:5555 shell am start -n com.clickeatenda.clickchannel/.MainActivity
```

### Tirar screenshot
```bash
adb -s 192.168.3.110:5555 shell screencap -p /sdcard/screenshot.png
adb -s 192.168.3.110:5555 pull /sdcard/screenshot.png
```

### Desinstalar app
```bash
# Fire Stick
adb -s 192.168.3.110:5555 uninstall com.clickeatenda.clickchannel

# Tablet
adb -s 192.168.3.159:5555 uninstall com.clickeatenda.clickchannel
```

---

## ✅ Checklist de Deploy

### Antes de compilar
- [ ] Código atualizado
- [ ] `flutter analyze` sem erros
- [ ] Versão atualizada no pubspec.yaml
- [ ] Changelog atualizado

### Durante deploy
- [ ] APK compilado com sucesso
- [ ] Fire Stick conectado
- [ ] Tablet conectado
- [ ] Instalação no Fire Stick OK
- [ ] Instalação no Tablet OK

### Após deploy
- [ ] App abre no Fire Stick
- [ ] App abre no Tablet
- [ ] Testar playlist
- [ ] Testar player
- [ ] Testar navegação

---

## 📝 Notas

- **Package name:** `com.clickeatenda.clickchannel`
- **APK location:** `build/app/outputs/flutter-apk/app-release.apk`
- **Build time:** ~2-5 minutos (dependendo do hardware)
- **APK size:** ~40-50 MB

---

## 🔗 Links

- **Issue GitHub:** https://github.com/clickeatenda/Click-Channel/issues/134
- **Repositório:** https://github.com/clickeatenda/Click-Channel-Final
- **ADB Documentation:** https://developer.android.com/tools/adb

---

**Última atualização:** 23/12/2025

