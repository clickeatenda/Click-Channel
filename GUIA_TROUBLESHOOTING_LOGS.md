# 🔧 Guia de Troubleshooting & Coleta de Logs

## 🚀 Se Tudo Funcionar (Esperado)

**Após configurar playlist M3U em Settings:**
```
Home → Categorias Filmes + Séries carregam em 5-10 segundos
      → Clique em uma categoria → Lista de filmes/séries aparece
      → Clique em um título → Abre detalhes + player
      → Clique PLAY → Vídeo começa a tocar
```

---

## ⚠️ Se Algo Não Funcionar

### Problema 1: Categorias Não Carregam (Filmes/Séries Vazios)

**Sintomas:**
- Home abre, mas seções "Filmes" e "Séries" estão vazias
- Ou mostra "Carregando..." por mais de 30 segundos

**Diagnóstico Rápido:**
1. **Verifique se a URL playlist é válida:**
   - Copie a URL do Settings
   - Paste no navegador do computador
   - Deve abrir um arquivo de texto com uma lista M3U

2. **Reinicie o app:**
   - Feche o app completamente
   - Abra novamente
   - Aguarde 15 segundos

3. **Limpe o cache:**
   - Settings → "Clear All Cache"
   - Volta para Settings → Cole URL novamente
   - Clique "Test Playlist" (deve mostrar ✅ se URL é válida)
   - Clique "Save"

**Se ainda não funcionar:**
- Pule para seção "Coleta de Logs" abaixo

---

### Problema 2: TMDB Ratings/Destaques Não Carregam

**Sintomas:**
- Categorias carregam OK (M3U funciona)
- Mas destaques Home estão vazios
- Ou ratings em detalhes de filme mostram "Não disponível"

**Diagnóstico Rápido:**
1. **Verifique Settings → TMDB Configuration:**
   - Campo "API Key" está preenchido?
   - Se não: Cole uma chave válida

2. **Teste a chave:**
   - Settings → TMDB Configuration
   - Clique "Test API Key"
   - Deve mostrar ✅ se a chave é válida
   - Se mostrar ❌: Chave é inválida ou expirada

3. **Obtenha nova chave:**
   - Vá para https://www.themoviedb.org/settings/api
   - Crie uma conta (se não tiver)
   - Clique "Create" para nova API Key (v3)
   - Copie a chave
   - Cole em Settings → "API Key"
   - Clique "Test API Key" → "Save"

**Se ainda não funcionar:**
- Pule para seção "Coleta de Logs" abaixo

---

### Problema 3: App Fecha/Crasha ao Abrir

**Sintomas:**
- App abre e fecha imediatamente
- Ou fica "carregando" infinitamente

**Diagnóstico Rápido:**
1. **Desinstale e reinstale:**
   ```bash
   adb uninstall com.example.clickflix
   adb install app-release.apk
   ```

2. **Se continua:** Pule para "Coleta de Logs"

---

## 📋 Coleta de Logs (Guia Detalhado)

### Pré-requisito: ADB Instalado
- ADB deve estar acessível via PowerShell
- Se não tiver, baixe em: https://developer.android.com/studio/releases/platform-tools

### Opção 1: Coleta Automática (PowerShell)

**Firestick:**
```powershell
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $adb -s 192.168.3.110:5555 logcat -d > "$env:USERPROFILE\Desktop\logs_firestick.txt"
Write-Host "✅ Logs salvos em: $env:USERPROFILE\Desktop\logs_firestick.txt"
```

**Tablet:**
```powershell
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $adb -s 192.168.3.155:39453 logcat -d > "$env:USERPROFILE\Desktop\logs_tablet.txt"
Write-Host "✅ Logs salvos em: $env:USERPROFILE\Desktop\logs_tablet.txt"
```

**Resultado:** Arquivo `logs_firestick.txt` / `logs_tablet.txt` na Desktop

---

### Opção 2: Coleta com Filtro (Apenas logs do app)

**Firestick (Flutter logs apenas):**
```powershell
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $adb -s 192.168.3.110:5555 logcat -d flutter > "$env:USERPROFILE\Desktop\logs_flutter_firestick.txt"
Write-Host "✅ Logs Flutter salvos"
```

**Tablet (Flutter logs apenas):**
```powershell
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $adb -s 192.168.3.155:39453 logcat -d flutter > "$env:USERPROFILE\Desktop\logs_flutter_tablet.txt"
Write-Host "✅ Logs Flutter salvos"
```

---

### Opção 3: Coleta em Tempo Real (Ao Abrir App)

**Executar ANTES de abrir o app:**

```powershell
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"

# Clear logs anteriores
& $adb -s 192.168.3.110:5555 logcat -c

# Comece a capturar (roda por 30 segundos)
Write-Host "📝 Capturando logs por 30 segundos..."
Start-Sleep 2
& $adb -s 192.168.3.110:5555 shell am start -S -W -n com.example.clickflix/com.example.clickflix.MainActivity

# Aguarde app abrir e carregue dados
Start-Sleep 30

# Salve logs
& $adb -s 192.168.3.110:5555 logcat -d > "$env:USERPROFILE\Desktop\logs_runtime_firestick.txt"
Write-Host "✅ Logs de runtime salvos"
```

---

## 🔍 O Que Procurar nos Logs

### Sinais de Sucesso ✅
```
✅ main: TMDB Service inicializado e configurado
✅ main: Playlist encontrada em Prefs
📦 main: Pré-carregando categorias...
✅ main: Categorias pré-carregadas com sucesso
```

### Sinais de Erro ❌
```
❌ [ERROR] TMDB: API key INVÁLIDA ou EXPIRADA! Status 401
   → Significa: chave TMDB expirada (configure nova via Settings)

❌ EXCEPTION in M3uService: ...
   → Significa: erro ao carregar playlist M3U

⚠️ main: SEM PLAYLIST CONFIGURADA
   → Significa: usuário ainda não configurou via Settings (esperado na primeira vez)
```

---

## 📧 O Que Enviar para Suporte

Se um problema persistir, colete e envie:

1. **Arquivo de logs completo**
   - `logs_firestick.txt` ou `logs_tablet.txt`
   
2. **Informações do problema**
   - O que você estava tentando fazer
   - O que aconteceu
   - Quando começou
   
3. **Configuração**
   - URL da playlist M3U (redacted: `http://...mp4`)
   - TMDB API key foi configurada? (sim/não)

---

## 🔄 Passos de Reset (Nuclear Option)

Se absolutamente nada funciona:

### Reset Completo do App

**Firestick:**
```powershell
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"

# Desinstale
& $adb -s 192.168.3.110:5555 uninstall com.example.clickflix
Write-Host "✅ App desinstalado"

Start-Sleep 3

# Reinstale
& $adb -s 192.168.3.110:5555 install app-release.apk
Write-Host "✅ App reinstalado"

# Abra
& $adb -s 192.168.3.110:5555 shell am start -n com.example.clickflix/com.example.clickflix.MainActivity
Write-Host "✅ App iniciado"
```

**Tablet:**
```powershell
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"

& $adb -s 192.168.3.155:39453 uninstall com.example.clickflix
Start-Sleep 3
& $adb -s 192.168.3.155:39453 install app-release.apk
& $adb -s 192.168.3.155:39453 shell am start -n com.example.clickflix/com.example.clickflix.MainActivity
```

---

## 📊 Análise de Logs (Exemplos)

### Log Bom (App Funcional)
```
12-29 10:16:47.343 15472 15472 I flutter : ✅ main: TMDB Service inicializado e configurado
12-29 10:16:47.366 15472 15472 I flutter : ℹ️ main: Nenhuma playlist salva encontrada
12-29 10:16:47.369 15472 15472 I flutter : ✅ main: TMDB Service inicializado e configurado
```
**Interpretação:** App iniciou OK, esperando config de usuário

### Log Ruim (Chave TMDB Expirada)
```
12-29 10:13:57.390 15217 15217 I flutter : ❌ [ERROR] ❌ TMDB: API key INVÁLIDA ou EXPIRADA! Status 401 (teste)
```
**Interpretação:** Chave TMDB do .env está expirada → usuário precisa configurar nova via Settings

### Log Ruim (Sem Playlist + Sem TMDB)
```
12-29 10:16:47.366 15472 15472 I flutter : ℹ️ main: Nenhuma playlist salva encontrada. Usuário precisa configurar via Setup.
12-29 10:13:57.390 15217 15217 I flutter : ❌ [ERROR] ❌ TMDB: API key INVÁLIDA ou EXPIRADA! Status 401
```
**Interpretação:** Tudo precisa ser configurado (esperado na primeira vez)

---

## 🎯 Checklist de Troubleshooting

- [ ] Categoria "Categorias vazias" → Verifique URL M3U
- [ ] "TMDB ratings vazios" → Verifique chave TMDB API
- [ ] "App crasha" → Desinstale e reinstale
- [ ] "Logs não ajudam" → Colete logs em tempo real (abra app durante captura)
- [ ] "Ainda não funciona" → Envie logs para suporte

---

## 💻 Comandos Úteis (Referência)

```powershell
# Iniciar app
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $adb -s 192.168.3.110:5555 shell am start -n com.example.clickflix/com.example.clickflix.MainActivity

# Fechar app
& $adb -s 192.168.3.110:5555 shell am force-stop com.example.clickflix

# Limpar dados de app
& $adb -s 192.168.3.110:5555 shell pm clear com.example.clickflix

# Coletar logs
& $adb -s 192.168.3.110:5555 logcat -d > logs.txt

# Ver logs em tempo real
& $adb -s 192.168.3.110:5555 logcat flutter

# Buscar erro específico em logs
& $adb -s 192.168.3.110:5555 logcat -d | Select-String -Pattern "ERROR|Exception"
```

---

## 📞 Contato para Suporte

Se após estes passos o problema persistir, envie:
1. Arquivo `logs_*.txt` coletado
2. Descrição do problema
3. Prints se possível

**Com essa informação, será possível diagnosticar o problema com precisão.**

---

**Última Atualização:** 29/12/2024  
**Versão APP:** 79.1MB (Release)
