# 🎬 Configuração TMDB API - Ratings e Metadados

## 📋 O Que Foi Implementado

Sistema completo de integração com **TMDB (The Movie Database)** para buscar:

- ✅ **Ratings reais** de filmes e séries (0-10)
- ✅ **Sinopses completas** em português
- ✅ **Gêneros** (Ação, Comédia, Drama, etc.)
- ✅ **Popularidade** (para ordenação "Mais Vistos")
- ✅ **Datas de lançamento** (para ordenação "Últimos Adicionados")
- ✅ **Elenco e diretor** (para tela de detalhes)
- ✅ **Orçamento e bilheteria** (para filmes)

---

## 🔑 Como Obter a Chave TMDB

### Passo 1: Criar Conta

1. Acesse: https://www.themoviedb.org/
2. Clique em **"Sign Up"** (canto superior direito)
3. Preencha o cadastro (é gratuito!)

### Passo 2: Obter API Key

1. Após fazer login, vá em: https://www.themoviedb.org/settings/api
2. Clique em **"Request an API Key"**
3. Escolha **"Developer"** (uso pessoal)
4. Preencha o formulário:
   - **Application Name:** Click Channel
   - **Application URL:** (deixe vazio ou coloque seu site)
   - **Application Summary:** App de streaming IPTV
5. Aceite os termos e clique em **"Submit"**
6. **Copie a API Key** que será gerada

### Passo 3: Adicionar no Projeto

1. Abra o arquivo `.env` na raiz do projeto
2. Adicione a linha:

```env
TMDB_API_KEY=sua_chave_aqui
```

**Exemplo:**
```env
TMDB_API_KEY=1234567890abcdef1234567890abcdef
```

3. **Salve o arquivo**

---

## ✅ Verificação

Após adicionar a chave:

1. **Reinicie o app** (hot restart não carrega .env novamente)
2. **Abra um filme ou série**
3. **Veja se aparece:**
   - ⭐ Rating com estrelas (se encontrado no TMDB)
   - 📝 Sinopse completa
   - 🏷️ Gêneros

---

## 🎯 Como Funciona

### 1. Enriquecimento Automático

Quando você carrega uma lista de filmes/séries:

1. App busca itens da playlist M3U
2. **Em background**, busca dados do TMDB para cada item
3. Atualiza ratings, sinopses e gêneros
4. Ordena listas automaticamente

### 2. Listas Inteligentes

Na tela inicial de **Filmes**, você verá:

- **Mais Vistos** - Ordenado por popularidade (TMDB)
- **Mais Avaliados** - Ordenado por rating (TMDB)
- **Últimos Adicionados** - Ordenado por data de lançamento

### 3. Tela de Detalhes

Ao abrir um filme/série:

- **Rating real** do TMDB (ex: 8.8/10)
- **Sinopse completa** em português
- **Gêneros** (ex: SCI-FI, THRILLER)
- **Elenco** com fotos
- **Diretor, orçamento, bilheteria**

---

## 🔍 Busca no TMDB

O app busca pelo **título** do filme/série. Se não encontrar:

- Tenta com o **ano** (se disponível)
- Faz busca **fuzzy** (títulos similares)
- Se não encontrar, usa dados da playlist M3U

---

## ⚠️ Limitações

- **Rate Limit:** TMDB permite ~40 requisições por 10 segundos
- **Cache:** Dados são buscados uma vez e reutilizados
- **Offline:** Se TMDB estiver offline, usa dados da playlist

---

## 🆘 Troubleshooting

### Problema: Ratings não aparecem

**Solução:**
1. Verifique se `TMDB_API_KEY` está no `.env`
2. Verifique se a chave está correta
3. Reinicie o app completamente

### Problema: Busca muito lenta

**Solução:**
- O enriquecimento acontece em background
- Apenas os primeiros 50 itens são enriquecidos
- Listas aparecem mesmo sem dados do TMDB

### Problema: Filme não encontrado

**Solução:**
- O título na playlist deve ser similar ao TMDB
- Tente ajustar o título na playlist M3U
- O app usa dados da playlist como fallback

---

## 📚 Documentação TMDB

- **Site oficial:** https://www.themoviedb.org/
- **Documentação API:** https://developers.themoviedb.org/3
- **Status da API:** https://status.themoviedb.org/

---

## 💡 Dicas

1. **Chave é gratuita** - Não precisa pagar
2. **Rate limit generoso** - 40 req/10s é suficiente
3. **Dados em português** - API suporta `language=pt-BR`
4. **Cache automático** - Não busca repetidamente

---

**Última atualização:** 23/12/2024  
**Status:** ✅ Implementado e pronto para uso

