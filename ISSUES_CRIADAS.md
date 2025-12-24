 apk novamente# 🔒 Issues de Segurança - Click Channel Final

**Status:** ✅ Todas criadas e configuradas no GitHub
**Data:** 23/12/2025
**Total:** 6 issues

---

## 🔴 URGENTE - Implementar IMEDIATAMENTE (3 issues)

### 1. Issue #128: Verificar e Remover .env do Histórico do Git
**🔗 Link direto:** https://github.com/clickeatenda/Click-Channel/issues/128

**Labels:**
- Infraestrutura
- Tarefa
- 🔴 Urgente
- 🚀 Sprint Atual

**Milestone:** Fase 1: Sistema de Design e Componentes

**O que fazer:**
```bash
# 1. Verificar se .env está no histórico
git log --all --full-history -- ".env"

# 2. Se encontrado, usar BFG Repo-Cleaner
git clone --mirror git@github.com:clickeatenda/Click-Channel-Final.git
java -jar bfg.jar --delete-files .env Click-Channel-Final.git
cd Click-Channel-Final.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push --force

# 3. Rotacionar todas as credenciais antigas
```

**Tempo estimado:** 1 dia

---

### 2. Issue #130: Implementar Certificate Pinning para Chamadas API
**🔗 Link direto:** https://github.com/clickeatenda/Click-Channel/issues/130

**Labels:**
- Aplicação Mobile
- Funcionalidade
- 🔴 Urgente
- 🔧 Em Desenvolvimento

**Milestone:** Fase 2: Funcionalidades Principais

**O que fazer:**
1. Adicionar `dio_certificate_pinning` no pubspec.yaml
2. Obter certificados SSL do backend
3. Configurar pinning no ApiClient
4. Testar em dev e produção

**Arquivos:**
- `lib/core/api/api_client.dart`
- `pubspec.yaml`
- `assets/certificates/` (criar)

**Tempo estimado:** 3 dias

---

### 3. Issue #131: Migrar Todas as Credenciais para Flutter Secure Storage
**🔗 Link direto:** https://github.com/clickeatenda/Click-Channel/issues/131

**Labels:**
- Aplicação Mobile
- Melhoria
- 🔴 Urgente
- 🔧 Em Desenvolvimento

**Milestone:** Fase 2: Funcionalidades Principais

**O que fazer:**
1. Auditar `lib/core/prefs.dart`
2. Migrar dados sensíveis para `flutter_secure_storage`
3. Remover armazenamento inseguro
4. Implementar migração automática

**Arquivos:**
- `lib/core/prefs.dart`
- `lib/providers/auth_provider.dart`
- `lib/data/m3u_service.dart`

**Tempo estimado:** 2 dias

---

## 🟠 ALTA - Implementar na próxima sprint (2 issues)

### 4. Issue #132: Remover/Desabilitar Logs que Expõem Dados Sensíveis
**🔗 Link direto:** https://github.com/clickeatenda/Click-Channel/issues/132

**Labels:**
- Aplicação Mobile
- Bug
- 🟠 Alta
- 🔧 Em Desenvolvimento

**Milestone:** Fase 4: Performance e Otimização

**O que fazer:**
1. Criar sistema de logging estruturado
2. Desabilitar `LogInterceptor` em produção
3. Substituir `print()` por logger apropriado
4. Implementar log sanitization

**Criar novo arquivo:**
```dart
// lib/core/utils/logger.dart
class AppLogger {
  static void debug(String message) {
    if (kDebugMode) print('🐛 $message');
  }
  
  static void error(String message) {
    print('❌ $message');
  }
}
```

**Tempo estimado:** 2 dias

---

### 5. Issue #133: Adicionar Validação e Sanitização de Inputs
**🔗 Link direto:** https://github.com/clickeatenda/Click-Channel/issues/133

**Labels:**
- Aplicação Mobile
- Funcionalidade
- 🟠 Alta
- 🚀 Sprint Atual

**Milestone:** Fase 2: Funcionalidades Principais

**O que fazer:**
1. Criar arquivo de validadores
2. Validar URLs (M3U, EPG)
3. Whitelist de protocolos
4. Validar email/senha no login

**Criar novo arquivo:**
```dart
// lib/core/utils/validators.dart
class Validators {
  static bool isValidUrl(String url) { }
  static bool isValidEmail(String email) { }
  static String sanitizeInput(String input) { }
}
```

**Tempo estimado:** 3 dias

---

## 🟡 MÉDIA - Backlog (1 issue)

### 6. Issue #129: Implementar Retry Strategy Seguro
**🔗 Link direto:** https://github.com/clickeatenda/Click-Channel/issues/129

**Labels:**
- Backend / API
- Melhoria
- 🟡 Média
- 📋 Backlog e Planejamento

**Milestone:** Fase 4: Performance e Otimização

**O que fazer:**
1. Aumentar timeouts (5s → 10-15s)
2. Adicionar `dio_retry` no pubspec.yaml
3. Implementar exponential backoff
4. Adicionar circuit breaker

**Tempo estimado:** 2 dias

---

## 📊 Estatísticas Finais

| Métrica | Valor |
|---------|-------|
| **Total de issues criadas** | 6 |
| **🔴 Urgente** | 3 |
| **🟠 Alta** | 2 |
| **🟡 Média** | 1 |
| **Tempo total estimado** | 13 dias |

---

## 🔗 Links Rápidos

### Ver todas as issues:
https://github.com/clickeatenda/Click-Channel-Final/issues

### Filtrar por prioridade:
- **🔴 Urgentes:** https://github.com/clickeatenda/Click-Channel-Final/issues?q=is%3Aissue+is%3Aopen+label%3A%22🔴+Urgente%22
- **🟠 Altas:** https://github.com/clickeatenda/Click-Channel-Final/issues?q=is%3Aissue+is%3Aopen+label%3A%22🟠+Alta%22
- **🟡 Médias:** https://github.com/clickeatenda/Click-Channel-Final/issues?q=is%3Aissue+is%3Aopen+label%3A%22🟡+Média%22

### Por milestone:
- **Fase 1:** https://github.com/clickeatenda/Click-Channel-Final/issues?q=is%3Aissue+milestone%3A%22Fase+1%3A+Sistema+de+Design+e+Componentes%22
- **Fase 2:** https://github.com/clickeatenda/Click-Channel-Final/issues?q=is%3Aissue+milestone%3A%22Fase+2%3A+Funcionalidades+Principais%22
- **Fase 4:** https://github.com/clickeatenda/Click-Channel-Final/issues?q=is%3Aissue+milestone%3A%22Fase+4%3A+Performance+e+Otimização%22

---

## 📅 Cronograma Sugerido

### Semana 1 (Sprint Urgente)
- **Dia 1:** Issue #128 - Limpar .env do histórico
- **Dias 2-4:** Issue #130 - Certificate Pinning
- **Dias 5-6:** Issue #131 - Secure Storage

### Semana 2-3 (Sprint Alta Prioridade)
- **Dias 1-3:** Issue #133 - Validação de Inputs
- **Dias 4-5:** Issue #132 - Logs Sensíveis

### Semana 4 (Backlog)
- **Dias 1-2:** Issue #129 - Retry Strategy

---

## ✅ Checklist de Implementação

### Antes de começar qualquer issue:
- [ ] Criar branch: `git checkout -b security/issue-XXX`
- [ ] Atualizar issue no GitHub para "Em Desenvolvimento"
- [ ] Ler toda a descrição da issue

### Durante desenvolvimento:
- [ ] Seguir critérios de aceitação
- [ ] Escrever testes unitários
- [ ] Documentar mudanças no código
- [ ] Testar localmente

### Antes do PR:
- [ ] Executar testes: `flutter test`
- [ ] Verificar lints: `flutter analyze`
- [ ] Testar em dispositivo físico
- [ ] Atualizar documentação se necessário

### Após merge:
- [ ] Fechar issue no GitHub
- [ ] Marcar no Notion (se aplicável)
- [ ] Deploy para ambiente de testes
- [ ] Validar em produção

---

## 🚨 ATENÇÃO - Segurança em Produção

**Antes de implementar em produção:**

1. ✅ Todas as 3 issues URGENTES devem ser resolvidas
2. ✅ Code review por 2+ desenvolvedores
3. ✅ Testes de penetração básicos
4. ✅ Rotação de credenciais antigas
5. ✅ Backup do banco de dados
6. ✅ Plano de rollback preparado

---

## 📞 Suporte

**Dúvidas sobre implementação:**
- Consultar documentação das issues no GitHub
- Revisar código existente em `lib/core/api/api_client.dart`
- Verificar `ROADMAP.md` para contexto

**Problemas durante implementação:**
- Comentar na issue específica no GitHub
- Marcar responsável técnico
- Consultar documentação oficial do Flutter

---

**Documento gerado automaticamente em 23/12/2025**
**Última atualização das issues:** 23/12/2025

