# 🔧 Como Habilitar ADB no Tablet

## ❌ Problema Atual

O tablet está **recusando conexão ADB**. Isso significa que o ADB Debugging não está habilitado.

---

## ✅ Solução: Habilitar ADB Debugging

### Passo 1: Ativar Modo Desenvolvedor

1. Abra **Configurações** no tablet
2. Role até **Sobre o tablet** (ou "Sobre o dispositivo")
3. Encontre **Número da versão** (ou "Build number")
4. Toque **7 vezes** no "Número da versão"
5. Aparecerá: "Você agora é um desenvolvedor!"

### Passo 2: Ativar Depuração USB

1. Volte para **Configurações**
2. Procure por **Opções do desenvolvedor** (agora visível)
3. Ative as seguintes opções:
   - ✅ **Opções do desenvolvedor** (ligar o switch principal)
   - ✅ **Depuração USB**
   - ✅ **Depuração USB (Modo de segurança)** (se disponível)

### Passo 3: Ativar Depuração por Rede (ADB via Wi-Fi)

Ainda em **Opções do desenvolvedor**:

1. Procure por **Depuração sem fio** ou **ADB por rede**
2. Ative esta opção
3. Anote o **IP** que aparecer (deve ser 192.168.3.159)

**OU** se não tiver esta opção:

1. Conecte o tablet ao PC via **cabo USB** (primeira vez)
2. No PC, execute:
   ```powershell
   adb tcpip 5555
   ```
3. Desconecte o cabo USB
4. No PC, execute:
   ```powershell
   adb connect 192.168.3.159:5555
   ```

---

## 🔄 Depois de Habilitar

### Conectar ao Tablet

```powershell
adb connect 192.168.3.159:5555
```

Deve aparecer:
```
connected to 192.168.3.159:5555
```

### Verificar Conexão

```powershell
adb devices
```

Deve aparecer:
```
List of devices attached
192.168.3.159:5555    device
```

### Executar Limpeza e Reinstalação

```powershell
.\limpar_e_reinstalar.ps1
```

---

## 🆘 Troubleshooting

### Problema: "connection refused"

**Causa:** ADB debugging não está habilitado  
**Solução:** Siga os passos acima

### Problema: "offline"

**Causa:** Tablet não autorizou o computador  
**Solução:**
1. No tablet, aparecerá um popup: "Permitir depuração USB?"
2. Marque ✅ "Sempre permitir deste computador"
3. Toque em **OK**

### Problema: "unauthorized"

**Causa:** Similar ao anterior  
**Solução:**
1. No PC: `adb kill-server`
2. No PC: `adb start-server`
3. No PC: `adb connect 192.168.3.159:5555`
4. No tablet: autorize quando popup aparecer

### Problema: IP diferente

**Causa:** Tablet tem IP diferente  
**Solução:**
1. No tablet, vá em **Configurações → Wi-Fi**
2. Toque na rede conectada
3. Veja o **Endereço IP**
4. Use esse IP para conectar:
   ```powershell
   adb connect SEU_IP:5555
   ```

---

## 📱 Alternativa: Desinstalar Manualmente

Se não conseguir conectar via ADB:

1. No tablet, vá em **Configurações**
2. **Apps** ou **Aplicativos**
3. Procure **Click Channel**
4. Toque em **Desinstalar**
5. Depois de desinstalar, instale o APK manualmente:
   - Copie o APK para o tablet
   - Abra o arquivo APK no tablet
   - Toque em **Instalar**

---

## 🎯 Próximos Passos

Após habilitar ADB e conectar:

1. ✅ Conectar: `adb connect 192.168.3.159:5555`
2. ✅ Limpar e reinstalar: `.\limpar_e_reinstalar.ps1`
3. ✅ Abrir app no tablet (deve estar limpo)

---

## 💡 Dica

Mantenha o **ADB Debugging habilitado** para facilitar deploys futuros!

