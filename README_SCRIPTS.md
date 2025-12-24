# 📜 Scripts de Build e Deploy - Guia Rápido

## 🎯 Resumo Executivo

Este projeto possui scripts automatizados para compilação limpa e deploy do APK no Fire TV Stick e Tablet.

---

## 📁 Scripts Disponíveis

| Script | Plataforma | Função |
|--------|------------|--------|
| `verificar_antes_build.ps1` | Windows | Verifica pré-requisitos antes do build |
| `verificar_antes_build.sh` | Linux/Mac | Verifica pré-requisitos antes do build |
| `build_clean.ps1` | Windows | Compila APK limpo (sem cache) |
| `build_clean.sh` | Linux/Mac | Compila APK limpo (sem cache) |
| `deploy.ps1` | Windows | Compila e instala nos dispositivos |
| `deploy.sh` | Linux/Mac | Compila e instala nos dispositivos |

---

## 🚀 Workflow Recomendado

### Windows (PowerShell)

```powershell
# Passo 1: Verificar pré-requisitos (opcional mas recomendado)
./verificar_antes_build.ps1

# Passo 2: Build limpo (OBRIGATÓRIO primeira vez)
./build_clean.ps1

# Passo 3: Deploy automático
./deploy.ps1
```

### Linux/Mac (Bash)

```bash
# Dar permissões de execução (primeira vez)
chmod +x *.sh

# Passo 1: Verificar pré-requisitos (opcional mas recomendado)
./verificar_antes_build.sh

# Passo 2: Build limpo (OBRIGATÓRIO primeira vez)
./build_clean.sh

# Passo 3: Deploy automático
./deploy.sh
```

---

## 📋 Detalhes dos Scripts

### 🔍 verificar_antes_build (Verificação)

**O que faz:**
- ✅ Verifica se Flutter está instalado
- ✅ Verifica se ADB está instalado
- ✅ Verifica estrutura do projeto
- ✅ Testa conectividade com dispositivos
- ✅ Detecta cache antigo

**Quando usar:**
- Primeira vez que vai fazer build
- Após atualizar Flutter/Android SDK
- Quando algo não funciona

**Exemplo de saída:**
```
✅ Flutter instalado e funcionando
✅ ADB instalado e funcionando
✅ pubspec.yaml encontrado
✅ Fire Stick acessível na rede
⚠️  Tablet não acessível (verifique se está ligado)
```

---

### 🧹 build_clean (Build Limpo)

**O que faz:**
1. Remove cache do Gradle (`android/.gradle`)
2. Remove builds anteriores (`android/build`)
3. Executa `flutter clean`
4. Atualiza dependências (`flutter pub get`)
5. Compila APK release sem cache

**Por que usar:**
- ✅ Garante APK limpo (sem dados pré-gravados)
- ✅ Remove artefatos de builds anteriores
- ✅ Previne problemas de cache
- ✅ Install marker funcionará corretamente

**Quando usar:**
- **OBRIGATÓRIO:** Primeira compilação para produção
- Depois de atualizar dependências
- Quando APK está com comportamento estranho
- Antes de release importante

**Tempo estimado:** 2-5 minutos

**Exemplo de saída:**
```
🧹 [1/5] Limpando build anterior...
   ✅ Build anterior removido

🗑️  [2/5] Removendo cache de desenvolvimento...
   ✅ Cache do Gradle removido

📦 [3/5] Atualizando dependências...
   ✅ Dependências atualizadas

🔨 [5/5] Compilando APK Release LIMPO...
   ✅ APK LIMPO COMPILADO COM SUCESSO!
   
📊 Informações do APK:
   • Localização: build/app/outputs/flutter-apk/app-release.apk
   • Tamanho: 45.2 MB
   • Status: SEM CACHE - Instalação limpa
```

---

### 🚀 deploy (Deploy Automático)

**O que faz:**
1. Compila APK release (se necessário)
2. Conecta ao Fire TV Stick (192.168.3.110:5555)
3. Conecta ao Tablet (192.168.3.159:5555)
4. Instala APK no Fire TV Stick
5. Instala APK no Tablet
6. Mostra resumo de instalação

**Quando usar:**
- Depois de fazer build limpo
- Para atualizar app nos dispositivos
- Deploy de nova versão

**Pré-requisitos:**
- ✅ Dispositivos ligados
- ✅ Dispositivos na mesma rede
- ✅ ADB habilitado nos dispositivos
- ✅ APK já compilado (ou será compilado automaticamente)

**Tempo estimado:** 1-3 minutos (se APK já existe)

**Exemplo de saída:**
```
📦 [1/4] Compilando APK Release...
   ✅ APK compilado com sucesso

📱 [2/4] Conectando aos dispositivos...
   ✅ Fire Stick conectado (192.168.3.110:5555)
   ✅ Tablet conectado (192.168.3.159:5555)

📲 [3/4] Instalando no Fire Stick...
   ✅ Instalado com sucesso

📲 [4/4] Instalando no Tablet...
   ✅ Instalado com sucesso

╔══════════════════════════════════════════════════════════╗
║           ✅ DEPLOY CONCLUÍDO COM SUCESSO!               ║
╚══════════════════════════════════════════════════════════╝
```

---

## 💡 Casos de Uso Comuns

### Primeiro Deploy (Build Limpo)

```powershell
# Windows
./verificar_antes_build.ps1  # Verificar setup
./build_clean.ps1            # Build limpo
./deploy.ps1                 # Deploy
```

```bash
# Linux/Mac
./verificar_antes_build.sh   # Verificar setup
./build_clean.sh             # Build limpo
./deploy.sh                  # Deploy
```

### Deploy Rápido (APK já existe)

```powershell
# Windows
./deploy.ps1
```

```bash
# Linux/Mac
./deploy.sh
```

### Apenas Compilar (sem deploy)

```powershell
# Windows
./build_clean.ps1
```

```bash
# Linux/Mac
./build_clean.sh
```

### Verificar Setup

```powershell
# Windows
./verificar_antes_build.ps1
```

```bash
# Linux/Mac
./verificar_antes_build.sh
```

---

## 🛠️ Troubleshooting

### Script não executa (Windows)

**Erro:** "Execução de scripts está desabilitada"

**Solução:**
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Script não executa (Linux/Mac)

**Erro:** "Permission denied"

**Solução:**
```bash
chmod +x *.sh
```

### Dispositivo não conecta

**Erro:** "device not found"

**Soluções:**
1. Verificar se dispositivo está ligado
2. Verificar se está na mesma rede
3. Verificar se ADB está habilitado no dispositivo
4. Tentar conectar manualmente:
   ```bash
   adb connect 192.168.3.110:5555  # Fire Stick
   adb connect 192.168.3.159:5555  # Tablet
   ```

### Build falha

**Erro:** "Build failed"

**Soluções:**
1. Executar `flutter doctor` e resolver problemas
2. Limpar cache global: `flutter pub cache repair`
3. Reexecutar `build_clean.ps1`

### APK ainda tem dados pré-gravados

**Solução:**
1. Desinstalar app dos dispositivos:
   ```bash
   adb -s 192.168.3.110:5555 uninstall com.clickeatenda.clickchannel
   adb -s 192.168.3.159:5555 uninstall com.clickeatenda.clickchannel
   ```
2. Executar build limpo: `./build_clean.ps1`
3. Reinstalar: `./deploy.ps1`

---

## 📱 Dispositivos Configurados

| Dispositivo | IP | Porta | Uso |
|-------------|-----|-------|-----|
| Fire TV Stick | 192.168.3.110 | 5555 | TV Principal |
| Tablet Android | 192.168.3.159 | 5555 | Dispositivo Móvel |

---

## 📚 Documentação Completa

Para mais detalhes, consulte:

- **`BUILD_CLEAN_EXPLANATION.md`** - Explicação técnica do problema do cache
- **`CORRECOES_APLICADAS.md`** - Resumo das correções aplicadas
- **`DEPLOYMENT_GUIDE.md`** - Guia completo de deployment manual
- **Issue #134:** [Compilação APK e Instalação](https://github.com/clickeatenda/Click-Channel/issues/134)

---

## ✅ Checklist de Deploy

- [ ] Executar `verificar_antes_build` (opcional)
- [ ] Dispositivos ligados e na rede
- [ ] ADB habilitado nos dispositivos
- [ ] Executar `build_clean` (primeira vez ou após mudanças importantes)
- [ ] Executar `deploy`
- [ ] Verificar app inicia na Setup Screen (sem lista pré-gravada)

---

**Última atualização:** 23/12/2024  
**Versão dos scripts:** 1.0.0  
**Status:** ✅ Produção

