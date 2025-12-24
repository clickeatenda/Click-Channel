# 🔧 Solução: App com Lista Antiga no Tablet

**Problema:** App no tablet ainda mostra lista M3U pré-configurada (antiga)

---

## 🐛 Causa Raiz

O APK foi instalado **por cima** (upgrade) de uma instalação anterior, mantendo:
- ✗ Cache de playlist antiga
- ✗ Preferências salvas
- ✗ Dados do usuário

O **Install Marker** não funciona em upgrades, apenas em instalações limpas.

---

## ✅ Solução: Desinstalar e Reinstalar Limpo

### Opção 1: Script Automático (Recomendado)

#### Pré-requisito: Habilitar ADB no Tablet

1. **Ativar Modo Desenvolvedor:**
   - Configurações → Sobre o tablet
   - Toque **7 vezes** em "Número da versão"

2. **Ativar Depuração USB:**
   - Configurações → Opções do desenvolvedor
   - Ative: **Depuração USB**
   - Ative: **Depuração sem fio** (se disponível)

3. **Conectar via ADB:**
   ```powershell
   adb connect 192.168.3.159:5555
   ```

4. **Executar Script de Limpeza:**
   ```powershell
   .\limpar_e_reinstalar.ps1
   ```

**O que o script faz:**
- ✅ Remove app completamente
- ✅ Limpa todos os dados e cache
- ✅ Deleta playlists antigas
- ✅ Instala versão limpa do zero

---

### Opção 2: Desinstalação Manual (Mais Simples)

Se não quiser configurar ADB:

#### No Tablet:

1. **Desinstalar o app:**
   - Configurações → Apps → Click Channel
   - Toque em **Desinstalar**
   - Confirme

2. **Limpar dados residuais (opcional mas recomendado):**
   - Configurações → Armazenamento
   - Dados em cache → Limpar cache

#### No PC:

3. **Verificar se APK existe:**
   ```powershell
   # Se não existe, compile primeiro:
   .\build_clean.ps1
   ```

4. **Transferir APK para tablet:**
   
   **Opção A: Via cabo USB**
   - Conecte tablet ao PC
   - Copie: `build\app\outputs\flutter-apk\app-release.apk`
   - Cole no tablet (pasta Downloads)
   
   **Opção B: Via e-mail/WhatsApp**
   - Envie o APK para você mesmo
   - Abra no tablet e baixe
   
   **Opção C: Via Google Drive/OneDrive**
   - Faça upload do APK
   - Baixe no tablet

5. **Instalar no tablet:**
   - Abra o arquivo `app-release.apk` no tablet
   - Toque em **Instalar**
   - (Se pedir, habilite "Instalar de fontes desconhecidas")

---

## 🎯 Resultado Esperado

Após desinstalar e reinstalar:

✅ App abre na **Setup Screen**  
✅ **Nenhuma playlist** pré-configurada  
✅ Usuário configura **manualmente** a playlist atual  
✅ Install marker criado corretamente  

---

## 🔍 Verificação

Após reinstalar, abra o app e verifique:

1. **Deve mostrar Setup Screen** (tela de configuração inicial)
2. **Não deve mostrar nenhum conteúdo** automaticamente
3. **Deve pedir URL da playlist**

Se ainda aparecer lista antiga:
- ❌ O problema está no **APK** (foi compilado com cache)
- ✅ Execute: `.\build_clean.ps1` e reinstale

---

## 📋 Comandos Rápidos

### Desinstalar via ADB (se habilitado):
```powershell
adb -s 192.168.3.159:5555 uninstall com.clickeatenda.clickchannel
```

### Instalar via ADB (se habilitado):
```powershell
adb -s 192.168.3.159:5555 install build\app\outputs\flutter-apk\app-release.apk
```

### Limpar e Reinstalar (automático):
```powershell
.\limpar_e_reinstalar.ps1
```

---

## 🆘 Troubleshooting

### Problema: "Instalar de fontes desconhecidas bloqueado"

**Solução:**
1. Quando tentar instalar, aparecerá popup
2. Toque em **Configurações**
3. Ative **Permitir desta fonte**
4. Volte e toque em **Instalar**

### Problema: ADB não conecta

**Solução:** Veja `COMO_HABILITAR_ADB_TABLET.md`

### Problema: App ainda tem lista antiga

**Solução:**
1. O APK foi compilado com cache
2. Execute build limpo:
   ```powershell
   .\build_clean.ps1
   ```
3. Desinstale do tablet
4. Reinstale o novo APK

---

## 📚 Documentação Relacionada

- **`limpar_e_reinstalar.ps1`** - Script automático de limpeza
- **`COMO_HABILITAR_ADB_TABLET.md`** - Guia completo de ADB
- **`build_clean.ps1`** - Script de build limpo
- **`COMECE_AQUI.md`** - Guia geral do projeto

---

## ✨ Resumo Executivo

**Para resolver rápido (manual):**

1. Desinstale o app no tablet (Configurações → Apps)
2. No PC, execute: `.\build_clean.ps1` (se ainda não fez)
3. Copie APK para tablet: `build\app\outputs\flutter-apk\app-release.apk`
4. Instale o APK no tablet
5. Abra o app → deve estar limpo!

---

**Última atualização:** 23/12/2024  
**Status:** ✅ Solução documentada e testável

