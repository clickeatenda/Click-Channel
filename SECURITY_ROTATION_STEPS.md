# Rotacionar chave TMDB (passos)

1) Gerar nova API Key no painel do TMDB
   - Acesse https://www.themoviedb.org/settings/api (faça login com sua conta TMDB).
   - Revoke / delete a chave antiga e gere uma nova API key (v4 ou v3 conforme usado pelo projeto).

2) Atualizar o ambiente local
   - No repositório, edite o arquivo `.env` (ou crie) e defina:
     TMDB_API_KEY=SEU_NOVO_VALOR
   - Verifique que `lib/core/config.dart` lê `TMDB_API_KEY` (já configurado).

3) Atualizar segredos do GitHub (CI)
   - Recomendo usar o script `scripts/rotate_tmdb_key.ps1` (Windows/PowerShell) que automatiza:
     - Atualiza/insere `TMDB_API_KEY` em `.env` local
     - Define o secret no repositório GitHub via `gh secret set TMDB_API_KEY --body "<key>"`
   - Pré-requisitos: GitHub CLI (`gh`) instalado e autenticado (`gh auth login`).

4) Verificar deploys/servidores
   - Atualize variáveis de ambiente em qualquer servidor, container ou CI que use a chave antiga.

5) Confirmar e revogar chave antiga
   - Após confirmar que tudo funciona com a nova chave, revogue a chave antiga no painel TMDB.

6) Auditoria final
   - Verifique com `git grep -n "19fad72344d2e286604239f434af5d3a"` ou `git log -S` localmente (não encontrará no histórico remoto se já foi purgado).
   - Certifique-se de que `.env` não seja comitado (adicionar ao `.gitignore` se necessário).

Se quiser, eu posso abrir a PR com esses arquivos ou executar passos interativos — preciso que você me forneça a nova chave TMDB (ou autentique o `gh` aqui) para eu definir o secret no repositório.
