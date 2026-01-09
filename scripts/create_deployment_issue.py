#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para criar issue de compilação e instalação no Firestick e Tablet
"""

import os
import sys
from dotenv import load_dotenv
from github import Github, Auth

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

load_dotenv()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "clickeatenda"
REPO_NAME = "Click-Channel-Final"

if not GITHUB_TOKEN:
    print("❌ GITHUB_TOKEN não configurado")
    exit(1)

auth = Auth.Token(GITHUB_TOKEN)
g = Github(auth=auth)

try:
    repo = g.get_user(REPO_OWNER).get_repo(REPO_NAME)
    print(f"✅ Conectado ao repositório: {REPO_OWNER}/{REPO_NAME}\n")
except Exception as e:
    print(f"❌ Erro: {e}")
    exit(1)

# Definir a issue de deployment
deployment_issue = {
    "title": "Compilação APK e Instalação no Firestick e Tablet",
    "body": """## 🚀 Compilação e Deploy para Dispositivos de Teste

### 📱 Dispositivos Alvo

| Dispositivo | IP | Porta ADB | Status |
|-------------|----|-----------:|--------|
| **Fire TV Stick** | `192.168.3.110` | 5555 | ⏳ Pendente |
| **Tablet** | `192.168.3.129` | 5555 | ⏳ Pendente |

---

## 📦 Passo 1: Compilar APK

### Opção A: APK Debug (Desenvolvimento)
```bash
# APK mais rápido para testar
flutter build apk --debug

# Localização do arquivo:
# build/app/outputs/flutter-apk/app-debug.apk
```

### Opção B: APK Release (Produção)
```bash
# APK otimizado e menor
flutter build apk --release

# Localização do arquivo:
# build/app/outputs/flutter-apk/app-release.apk
```

### Opção C: App Bundle (Para Google Play)
```bash
# Formato recomendado para Play Store
flutter build appbundle --release

# Localização do arquivo:
# build/app/outputs/bundle/release/app-release.aab
```

### ✅ Verificar APK gerado
```bash
# Listar APKs gerados
ls -lh build/app/outputs/flutter-apk/

# Informações do APK
aapt dump badging build/app/outputs/flutter-apk/app-release.apk | grep package
```

---

## 🔧 Passo 2: Preparar Dispositivos

### Fire TV Stick (192.168.3.110)

#### 1. Habilitar ADB no Fire Stick
1. Ir para **Configurações** > **Minha Fire TV**
2. Selecionar **Opções do Desenvolvedor**
3. Ativar **Depuração ADB**
4. Ativar **Apps de Fontes Desconhecidas**

#### 2. Conectar via ADB
```bash
# Conectar ao Fire Stick
adb connect 192.168.3.110:5555

# Verificar se conectou
adb devices
# Deve mostrar: 192.168.3.110:5555    device
```

---

### Tablet (192.168.3.129)

#### 1. Habilitar Modo Desenvolvedor no Tablet
1. Ir para **Configurações** > **Sobre o Telefone/Tablet**
2. Tocar 7 vezes em **Número da Compilação**
3. Voltar e entrar em **Opções do Desenvolvedor**
4. Ativar **Depuração USB**
5. Ativar **Depuração por rede** (se disponível)

#### 2. Conectar via ADB
```bash
# Se via USB:
adb devices

# Se via WiFi:
adb tcpip 5555
adb connect 192.168.3.129:5555

# Verificar conexão
adb devices
# Deve mostrar: 192.168.3.129:5555    device
```

---

## 📲 Passo 3: Instalar APK nos Dispositivos

### Instalação Automática (Ambos os Dispositivos)

Criar script `deploy.sh` ou `deploy.ps1`:

**PowerShell (Windows):**
```powershell
# deploy.ps1
$APK_PATH = "build/app/outputs/flutter-apk/app-release.apk"
$FIRESTICK_IP = "192.168.3.110"
$TABLET_IP = "192.168.3.129"

Write-Host "🚀 Compilando APK..." -ForegroundColor Cyan
flutter build apk --release

Write-Host "`n📦 APK compilado com sucesso!`n" -ForegroundColor Green

# Conectar dispositivos
Write-Host "🔌 Conectando dispositivos..." -ForegroundColor Cyan
adb connect ${FIRESTICK_IP}:5555
adb connect ${TABLET_IP}:5555

Start-Sleep -Seconds 2

# Listar dispositivos conectados
Write-Host "`n📱 Dispositivos conectados:" -ForegroundColor Yellow
adb devices

# Instalar no Fire Stick
Write-Host "`n📲 Instalando no Fire Stick (${FIRESTICK_IP})..." -ForegroundColor Cyan
adb -s ${FIRESTICK_IP}:5555 install -r $APK_PATH
Write-Host "✅ Instalado no Fire Stick!" -ForegroundColor Green

# Instalar no Tablet
Write-Host "`n📲 Instalando no Tablet (${TABLET_IP})..." -ForegroundColor Cyan
adb -s ${TABLET_IP}:5555 install -r $APK_PATH
Write-Host "✅ Instalado no Tablet!" -ForegroundColor Green

Write-Host "`n🎉 Deploy completo!" -ForegroundColor Green
Write-Host "📱 App instalado em 2 dispositivos`n" -ForegroundColor Cyan
```

**Bash (Linux/Mac):**
```bash
#!/bin/bash
# deploy.sh

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
FIRESTICK_IP="192.168.3.110"
TABLET_IP="192.168.3.129"

echo "🚀 Compilando APK..."
flutter build apk --release

echo ""
echo "📦 APK compilado com sucesso!"
echo ""

# Conectar dispositivos
echo "🔌 Conectando dispositivos..."
adb connect ${FIRESTICK_IP}:5555
adb connect ${TABLET_IP}:5555

sleep 2

# Listar dispositivos
echo ""
echo "📱 Dispositivos conectados:"
adb devices

# Instalar no Fire Stick
echo ""
echo "📲 Instalando no Fire Stick (${FIRESTICK_IP})..."
adb -s ${FIRESTICK_IP}:5555 install -r $APK_PATH
echo "✅ Instalado no Fire Stick!"

# Instalar no Tablet
echo ""
echo "📲 Instalando no Tablet (${TABLET_IP})..."
adb -s ${TABLET_IP}:5555 install -r $APK_PATH
echo "✅ Instalado no Tablet!"

echo ""
echo "🎉 Deploy completo!"
echo "📱 App instalado em 2 dispositivos"
```

### Executar Script
```bash
# Windows
./deploy.ps1

# Linux/Mac
chmod +x deploy.sh
./deploy.sh
```

---

### Instalação Manual

#### Fire Stick (192.168.3.110)
```bash
# 1. Conectar
adb connect 192.168.3.110:5555

# 2. Instalar
adb -s 192.168.3.110:5555 install -r build/app/outputs/flutter-apk/app-release.apk

# 3. Iniciar app (opcional)
adb -s 192.168.3.110:5555 shell monkey -p com.clickeatenda.clickchannel -c android.intent.category.LAUNCHER 1
```

#### Tablet (192.168.3.129)
```bash
# 1. Conectar
adb connect 192.168.3.129:5555

# 2. Instalar
adb -s 192.168.3.129:5555 install -r build/app/outputs/flutter-apk/app-release.apk

# 3. Iniciar app (opcional)
adb -s 192.168.3.129:5555 shell am start -n com.clickeatenda.clickchannel/.MainActivity
```

---

## 🔍 Passo 4: Verificação e Testes

### Verificar Instalação
```bash
# Listar apps instalados (verificar se Click Channel está lá)
adb -s 192.168.3.110:5555 shell pm list packages | grep clickchannel
adb -s 192.168.3.129:5555 shell pm list packages | grep clickchannel
```

### Ver Logs em Tempo Real
```bash
# Fire Stick
adb -s 192.168.3.110:5555 logcat | grep -i flutter

# Tablet
adb -s 192.168.3.129:5555 logcat | grep -i flutter
```

### Desinstalar (se necessário)
```bash
# Fire Stick
adb -s 192.168.3.110:5555 uninstall com.clickeatenda.clickchannel

# Tablet
adb -s 192.168.3.129:5555 uninstall com.clickeatenda.clickchannel
```

---

## 🐛 Troubleshooting

### Problema: "adb: device offline"
```bash
# Desconectar e reconectar
adb disconnect 192.168.3.110:5555
adb connect 192.168.3.110:5555
```

### Problema: "adb: device unauthorized"
```bash
# No dispositivo, aceitar a autorização ADB que aparecerá na tela
# Depois reconectar
adb connect 192.168.3.110:5555
```

### Problema: Não consegue conectar via IP
```bash
# 1. Verificar se dispositivo está na mesma rede
ping 192.168.3.110
ping 192.168.3.129

# 2. Verificar se ADB está habilitado no dispositivo

# 3. Testar porta diferente (algumas TVs usam porta 5555, outras 5037)
adb connect 192.168.3.110:5037
```

### Problema: APK não instala ("INSTALL_FAILED_UPDATE_INCOMPATIBLE")
```bash
# Desinstalar versão antiga primeiro
adb -s 192.168.3.110:5555 uninstall com.clickeatenda.clickchannel
# Instalar novamente
adb -s 192.168.3.110:5555 install -r build/app/outputs/flutter-apk/app-release.apk
```

### Problema: App trava ao abrir
```bash
# Ver logs de erro
adb -s 192.168.3.110:5555 logcat -d | grep -i "flutter\\|crash\\|error"

# Limpar cache do app
adb -s 192.168.3.110:5555 shell pm clear com.clickeatenda.clickchannel
```

---

## 📋 Checklist de Deploy

### Pré-Deploy
- [ ] Código atualizado e testado localmente
- [ ] `flutter analyze` sem erros
- [ ] `flutter test` passando
- [ ] Versão atualizada no `pubspec.yaml`
- [ ] Changelog atualizado

### Compilação
- [ ] APK compilado com sucesso
- [ ] Tamanho do APK verificado (ideal < 50MB)
- [ ] Assinatura verificada (se release)

### Instalação
- [ ] Fire Stick conectado via ADB
- [ ] Tablet conectado via ADB
- [ ] APK instalado no Fire Stick
- [ ] APK instalado no Tablet

### Testes
- [ ] App abre no Fire Stick
- [ ] App abre no Tablet
- [ ] Playlist carrega corretamente
- [ ] Player funciona (testar canal)
- [ ] Navegação por controle remoto (Fire Stick)
- [ ] Navegação touch (Tablet)
- [ ] Sem crashes ou erros visíveis

### Pós-Deploy
- [ ] Feedback dos usuários coletado
- [ ] Issues identificadas documentadas
- [ ] Próxima versão planejada

---

## 🚀 Comandos Rápidos (Cheat Sheet)

```bash
# Compilar e instalar em um comando
flutter build apk --release && \\
adb connect 192.168.3.110:5555 && \\
adb connect 192.168.3.129:5555 && \\
adb -s 192.168.3.110:5555 install -r build/app/outputs/flutter-apk/app-release.apk && \\
adb -s 192.168.3.129:5555 install -r build/app/outputs/flutter-apk/app-release.apk

# Verificar conexão dos dispositivos
adb devices

# Desconectar todos os dispositivos
adb disconnect

# Ver logs do app em tempo real
adb logcat | grep -i "flutter\\|clickchannel"

# Screenshot do dispositivo
adb -s 192.168.3.110:5555 shell screencap -p /sdcard/screenshot.png
adb -s 192.168.3.110:5555 pull /sdcard/screenshot.png

# Gravar vídeo da tela (útil para bugs)
adb -s 192.168.3.110:5555 shell screenrecord /sdcard/demo.mp4
# Parar: Ctrl+C
adb -s 192.168.3.110:5555 pull /sdcard/demo.mp4
```

---

## 📊 Informações dos Dispositivos

### Fire TV Stick (192.168.3.110)
- **Resolução:** 1920x1080 (Full HD)
- **Input:** Controle remoto + D-Pad
- **Performance:** Otimizado para low-end
- **Navegação:** Foco baseado em teclas direcionais

### Tablet (192.168.3.129)
- **Resolução:** Variável (verificar nas configurações)
- **Input:** Touch screen + gestos
- **Performance:** Média/Alta
- **Navegação:** Touch e scroll

---

## 🔗 Links Úteis

- [Flutter Build & Release - Android](https://docs.flutter.dev/deployment/android)
- [ADB Wireless Debugging](https://developer.android.com/tools/adb#wireless)
- [Fire TV Development](https://developer.amazon.com/docs/fire-tv/connecting-adb-to-device.html)

---

**Labels:**
- Deployment
- Testing
- Fire TV
- Android

**Milestone:** Fase 5: Implantação e Monitoramento

**Prioridade:** 🟠 Alta

**Dispositivos:**
- Fire TV Stick: `192.168.3.110:5555`
- Tablet: `192.168.3.129:5555`
""",
    "labels": ["Aplicação Mobile", "Tarefa", "🟠 Alta", "🔧 Em Desenvolvimento"],
    "milestone": "Fase 5: Implantação e Monitoramento"
}

print("=" * 70)
print("🚀 CRIANDO ISSUE DE DEPLOYMENT")
print("=" * 70)

try:
    # Verificar se já existe
    existing = False
    for issue in repo.get_issues(state='all'):
        if issue.title == deployment_issue['title']:
            print(f"\n⏭️  Issue já existe: #{issue.number}")
            print(f"🔗 {issue.html_url}")
            existing = True
            break
    
    if not existing:
        # Buscar milestone
        milestone = None
        for m in repo.get_milestones(state='all'):
            if m.title == deployment_issue['milestone']:
                milestone = m
                break
        
        # Criar issue
        new_issue = repo.create_issue(
            title=deployment_issue['title'],
            body=deployment_issue['body'],
            labels=deployment_issue['labels'],
            milestone=milestone
        )
        
        print(f"\n✅ Issue criada com sucesso!")
        print(f"📝 Número: #{new_issue.number}")
        print(f"📌 Título: {new_issue.title}")
        print(f"🔗 URL: {new_issue.html_url}")
        print(f"🏷️  Labels: {', '.join(deployment_issue['labels'])}")
        print(f"📊 Milestone: {deployment_issue['milestone']}")
        
except Exception as e:
    print(f"\n❌ Erro ao criar issue: {e}")
    exit(1)

print("\n" + "=" * 70)
print("✨ Processo concluído!")
print("=" * 70)

