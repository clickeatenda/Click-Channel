# 🚀 COMECE AQUI - Deploy Click Channel

> **Última atualização:** 23/12/2024  
> **Status:** ✅ Pronto para produção

---

## ⚡ Início Rápido (3 comandos)

### Windows (PowerShell)

```powershell
# 1. Verificar pré-requisitos (opcional)
.\verificar_antes_build.ps1

# 2. Build limpo (OBRIGATÓRIO)
.\build_clean.ps1

# 3. Deploy automático
.\deploy.ps1
```

### Linux/Mac (Bash)

```bash
# 0. Dar permissão (primeira vez)
chmod +x *.sh

# 1. Verificar pré-requisitos (opcional)
./verificar_antes_build.sh

# 2. Build limpo (OBRIGATÓRIO)
./build_clean.sh

# 3. Deploy automático
./deploy.sh
```

---

## 📱 Dispositivos

| Dispositivo | IP | Porta |
|-------------|-----|-------|
| **Fire TV Stick** | 192.168.3.110 | 5555 |
| **Tablet Android** | 192.168.3.159 | 5555 |

---

## 🐛 Problemas Resolvidos

✅ **Problema 1:** APK estava com lista M3U pré-gravada  
**Solução:** Scripts de build limpo criados (`build_clean.ps1/sh`)

✅ **Problema 2:** IP do tablet incorreto (129 → 159)  
**Solução:** Todos os scripts atualizados com IP correto

---

## 📚 Documentação

| Documento | Para Que Serve |
|-----------|----------------|
| **`README_SCRIPTS.md`** | 📖 **LEIA PRIMEIRO!** Guia completo dos scripts |
| `BUILD_CLEAN_EXPLANATION.md` | 🔍 Explicação técnica do problema |
| `CORRECOES_APLICADAS.md` | 📋 Resumo executivo das correções |
| `DEPLOYMENT_GUIDE.md` | 📖 Guia de deploy manual (avançado) |

---

## 🎯 O Que Cada Script Faz

### verificar_antes_build
✅ Verifica Flutter, ADB, conectividade  
⏱️ Tempo: 5 segundos

### build_clean ⭐ IMPORTANTE
🧹 Remove cache e compila APK limpo  
⏱️ Tempo: 2-5 minutos  
**Use sempre antes de release!**

### deploy
🚀 Instala nos dispositivos automaticamente  
⏱️ Tempo: 1-3 minutos

---

## ✨ Resultado Esperado

Após executar os scripts:

1. ✅ APK compilado **SEM cache**
2. ✅ App instalado no **Fire TV Stick** (192.168.3.110)
3. ✅ App instalado no **Tablet** (192.168.3.159)
4. ✅ App inicia na **Setup Screen** (sem lista pré-configurada)
5. ✅ Usuário configura playlist **manualmente**

---

## 🆘 Ajuda Rápida

### Dispositivo não conecta?

```bash
# Verificar dispositivos
adb devices

# Reconectar manualmente
adb connect 192.168.3.110:5555  # Fire Stick
adb connect 192.168.3.159:5555  # Tablet
```

### Build falha?

```bash
# Verificar Flutter
flutter doctor

# Limpar cache global
flutter pub cache repair

# Reexecutar build limpo
.\build_clean.ps1
```

### APK ainda tem dados?

```bash
# Desinstalar dos dispositivos
adb -s 192.168.3.110:5555 uninstall com.clickeatenda.clickchannel
adb -s 192.168.3.159:5555 uninstall com.clickeatenda.clickchannel

# Recompilar limpo
.\build_clean.ps1

# Reinstalar
.\deploy.ps1
```

---

## 🔗 Links Úteis

- **Issue no GitHub:** [#134 - Compilação APK e Instalação](https://github.com/clickeatenda/Click-Channel/issues/134)
- **Repositório:** [Click-Channel](https://github.com/clickeatenda/Click-Channel)

---

## ✅ Checklist de Deploy

Antes de começar:

- [ ] Flutter instalado (`flutter --version`)
- [ ] ADB instalado (`adb version`)
- [ ] Dispositivos ligados e na rede
- [ ] ADB habilitado nos dispositivos

Durante o deploy:

- [ ] Executar `verificar_antes_build` (opcional)
- [ ] Executar `build_clean` **(OBRIGATÓRIO)**
- [ ] Executar `deploy`

Após o deploy:

- [ ] App instalado no Fire Stick
- [ ] App instalado no Tablet
- [ ] App inicia na Setup Screen
- [ ] Não há lista pré-configurada

---

## 💡 Dicas

1. **Sempre use `build_clean` antes de releases importantes**
2. Se tiver dúvidas, leia `README_SCRIPTS.md`
3. Para deploy rápido (sem recompilar): apenas `.\deploy.ps1`
4. Mantenha os dispositivos na mesma rede Wi-Fi

---

## 🎊 Pronto!

Execute os 3 comandos acima e está pronto! 🚀

Para mais detalhes, consulte **`README_SCRIPTS.md`**.

---

**Dúvidas?** Consulte a [Issue #134](https://github.com/clickeatenda/Click-Channel/issues/134)

