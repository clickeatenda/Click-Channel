# 🐛 Problema: Cache Antigo Persistindo Entre Instalações

## 📋 Descrição do Problema

O usuário reportou que uma **playlist de canais fantasma** aparecia após reinstalar o aplicativo, mesmo sem ter configurado nenhuma playlist.

## 🔍 Causa Raiz Identificada

### **Android Auto-Backup**

Por padrão, o Android faz **backup automático** dos dados do aplicativo quando:
1. O app é desinstalado
2. O dispositivo sincroniza com a conta Google

Quando o app é **reinstalado**, o Android **restaura automaticamente**:
- SharedPreferences (`Prefs`)
- Arquivos em `getApplicationSupportDirectory()`
- Outros dados persistentes

### **Onde o Cache é Salvo**

```dart
// lib/data/m3u_service.dart linha 253
static Future<File> _getCacheFile(String source) async {
  final dir = await getApplicationSupportDirectory(); // ⚠️ PERSISTE ENTRE INSTALAÇÕES
  final safe = source.hashCode;
  final filePath = '${dir.path}/m3u_cache_$safe.m3u';
  return File(filePath);
}
```

### **Fluxo do Problema**

1. **Instalação Anterior**:
   - Usuário configura playlist → Cache salvo em `getApplicationSupportDirectory()`
   - Android faz backup automático dos dados

2. **Desinstalação**:
   - App removido, mas backup permanece no Google

3. **Reinstalação**:
   - Android restaura automaticamente:
     - ✅ SharedPreferences (URLs, configurações)
     - ✅ Arquivos de cache (`m3u_cache_*.m3u`)
   - **Resultado**: Cache antigo aparece como "lista fantasma"

## ✅ Solução Implementada

### **1. Desabilitar Android Auto-Backup**

**Arquivo**: `android/app/src/main/AndroidManifest.xml`

```xml
<application
    android:label="Click Channel"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:usesCleartextTraffic="true"
    android:allowBackup="false"           <!-- ✅ ADICIONADO -->
    android:fullBackupContent="false">    <!-- ✅ ADICIONADO -->
```

**Efeito**:
- ❌ Android **NÃO fará mais backup** dos dados do app
- ✅ Desinstalação = **limpeza completa** dos dados
- ✅ Reinstalação = **app totalmente limpo**

### **2. Limpeza Agressiva na Primeira Execução**

**Arquivo**: `lib/main.dart` (linhas 66-106)

Já implementado:
- ✅ Detecta primeira execução (sem install marker)
- ✅ Limpa **TODOS** os caches (memória + disco)
- ✅ Remove **TODOS** os arquivos `m3u_cache_*.m3u`
- ✅ Limpa SharedPreferences

### **3. Verificação de URL em Prefs vs Cache**

**Arquivo**: `lib/data/m3u_service.dart` (linhas 606-618)

```dart
// Se cache existe mas não há URL salva em Prefs, deleta cache
if (normalizedSaved.isEmpty) {
  print('⚠️ Cache existe mas não há URL salva em Prefs! Deletando...');
  await file.delete();
}
```

## 🧪 Como Testar

### **Teste 1: Nova Instalação**
```bash
# Desinstalar completamente
adb uninstall com.example.clickchannel

# Reinstalar
adb install app-release.apk

# Resultado esperado:
# ✅ App abre SEM conteúdo
# ✅ Solicita configuração de playlist
# ✅ NÃO mostra lista de canais fantasma
```

### **Teste 2: Reinstalação com Backup Antigo**
```bash
# Se o dispositivo tem backup antigo do Google:
# 1. Desinstale o app
# 2. Aguarde alguns minutos (sincronização)
# 3. Reinstale

# Com a correção:
# ✅ App detecta primeira execução
# ✅ Limpa TODOS os dados restaurados do backup
# ✅ Inicia totalmente limpo
```

## 📊 Comparação: Antes vs Depois

| Cenário | Antes | Depois |
|---------|-------|--------|
| Nova instalação | ✅ Limpo | ✅ Limpo |
| Reinstalação (sem backup) | ✅ Limpo | ✅ Limpo |
| Reinstalação (com backup Android) | ❌ Cache restaurado | ✅ Limpo (backup desabilitado) |
| Atualização (manter dados) | ✅ Mantém dados | ✅ Mantém dados |

## 🎯 Impacto nas Funcionalidades

### **Mantido**:
- ✅ Cache persiste entre **fechamentos do app**
- ✅ Cache persiste entre **reinicializações do dispositivo**
- ✅ Cache persiste em **atualizações do app** (mesma versão instalada por cima)

### **Removido**:
- ❌ Backup automático do Android (agora desabilitado)
- ❌ Restauração de dados em nova instalação

### **Usuário Precisará**:
- ⚠️ Reconfigurar playlist se **desinstalar e reinstalar**
- ⚠️ Reconfigurar playlist se **trocar de dispositivo**

## 📝 Notas Técnicas

### **Por que `getApplicationSupportDirectory()`?**

Usamos `getApplicationSupportDirectory()` (em vez de `getTemporaryDirectory()`) porque:
- ✅ Cache deve persistir entre sessões
- ✅ Cache NÃO deve ser limpo pelo sistema automaticamente
- ✅ Cache é grande (~100MB para 374k itens)

Mas isso tem o efeito colateral de:
- ⚠️ Ser incluído no backup do Android (AGORA DESABILITADO)

### **Alternativas Consideradas**

1. **`getTemporaryDirectory()`**:
   - ❌ Sistema pode limpar a qualquer momento
   - ❌ Perderia cache entre reinicializações

2. **`getExternalStorageDirectory()`**:
   - ❌ Requer permissão WRITE_EXTERNAL_STORAGE
   - ❌ Acessível por outros apps (problema de segurança)

3. **`getApplicationDocumentsDirectory()`**:
   - ❌ Mesmo problema de backup do Android

## ✅ Conclusão

Com `android:allowBackup="false"`:
- ✅ App sempre inicia **completamente limpo** após reinstalação
- ✅ Não há "cache fantasma" de instalações anteriores
- ✅ Comportamento **100% previsível e determinístico**

**Data da Correção**: 27/12/2024
**Commit**: Desabilitar Android Auto-Backup para evitar cache antigo

