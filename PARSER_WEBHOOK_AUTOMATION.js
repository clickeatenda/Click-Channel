// ========================================
// PARSER 2 - WEBHOOK AUTOMATION
// ========================================
// Para usar com Webhook do GitHub
// Automação: cria/atualiza no Notion quando issue é criada/atualizada

// Entrada bruta do Webhook
let raw = $input.item.json;

// Pode vir em body (string JSON) ou em payload
if (raw.body) {
  try {
    raw = typeof raw.body === 'string' ? JSON.parse(raw.body) : raw.body;
  } catch (e) {}
}

if (raw.payload) {
  try {
    raw = typeof raw.payload === 'string' ? JSON.parse(raw.payload) : raw.payload;
  } catch (e) {}
}

// Webhook do GitHub sempre tem 'issue' e 'repository'
const issue = raw.issue || {};
const repo  = raw.repository || {};

// Detectar repositório de múltiplas fontes
let repoFullName = repo.full_name || '';
let repoName = repo.name || '';

// Se não tiver repositório, tenta extrair da URL
if (!repoName && issue.repository_url) {
  const urlMatch = issue.repository_url.match(/repos\/([^\/]+)\/([^\/]+)$/);
  if (urlMatch) {
    repoFullName = `${urlMatch[1]}/${urlMatch[2]}`;
    repoName = urlMatch[2];
  }
}

// Se ainda não tiver, tenta da URL da issue
if (!repoName && issue.url) {
  const urlMatch = issue.url.match(/repos\/([^\/]+)\/([^\/]+)\/issues/);
  if (urlMatch) {
    repoFullName = `${urlMatch[1]}/${urlMatch[2]}`;
    repoName = urlMatch[2];
  }
}

// Se ainda não tiver, tenta da html_url
if (!repoName && issue.html_url) {
  const urlMatch = issue.html_url.match(/github\.com\/([^\/]+)\/([^\/]+)\/issues/);
  if (urlMatch) {
    repoFullName = `${urlMatch[1]}/${urlMatch[2]}`;
    repoName = urlMatch[2];
  }
}

// Fallback final
if (!repoName) {
  repoFullName = 'unknown/REPOSITORIO_NAO_DETECTADO';
  repoName = 'REPOSITORIO_NAO_DETECTADO';
}

// Labels - pode vir como array de objetos
const labels = (issue.labels || []).map(l => {
  if (typeof l === 'object' && l.name) {
    return l.name.toLowerCase();
  }
  return (l || '').toLowerCase();
});

// Péga o título REAL
const issueNumber = issue.number || 0;
const issueTitle = (issue.title && issue.title.trim()) ? issue.title.trim() : '';

// Se não tiver título, pula
if (!issueTitle) {
  return { json: {} };
}

const issueUrl       = issue.html_url || '';
const issueState     = issue.state || 'open';
const issueCreatedAt = issue.created_at || new Date().toISOString();
const issueUpdatedAt = issue.updated_at || new Date().toISOString();
const uniqueId       = `${repoFullName}#${issueNumber}`;

// Descrição - trunca para 2000 chars (limite Notion)
let issueBody = issue.body || '';
if (issueBody && issueBody.length > 2000) {
  issueBody = issueBody.substring(0, 1997) + '...';
}
const descricao = issueBody && issueBody.trim() ? issueBody.trim() : issueTitle;

// ---------- ANTI-LOOP (IMPORTANTE para webhook) ----------
const cacheKey   = `webhook_${uniqueId}`;
const now        = Date.now();
const staticData = $getWorkflowStaticData('global');
const lastRun    = staticData[cacheKey];

if (lastRun && (now - lastRun) < 5 * 1000) {
  // Se essa mesma issue passou pelo webhook há menos de 5 segundos,
  // não processa novamente (evita loop infinito)
  return [];
}

// Atualiza o cache
staticData[cacheKey] = now;

// ---------- Derivado de labels ----------

let prioridade = 'Média';
if (labels.includes('alta'))  prioridade = 'Alta';
if (labels.includes('urgente')) prioridade = 'Urgente';
if (labels.includes('baixa')) prioridade = 'Baixa';

// Auto-detectar tipo de projeto pelo nome do repositório
let tipoProjeto = 'Desconhecido';
const repoLower = repoName.toLowerCase();

if (repoLower.includes('channel') || repoLower.includes('clickflix')) {
  tipoProjeto = 'Aplicação Mobile';
} else if (repoLower.includes('studio') || repoLower.includes('dashboard') || repoLower.includes('web') || repoLower.includes('finance')) {
  tipoProjeto = 'Aplicação WEB';
} else if (repoLower.includes('land-page') || repoLower.includes('landing')) {
  tipoProjeto = 'Landing Page';
} else if (repoLower.includes('backend') || repoLower.includes('api')) {
  tipoProjeto = 'Backend / API';
} else if (repoLower.includes('infra') || repoLower.includes('devops')) {
  tipoProjeto = 'Infraestrutura';
}

let tipo = 'Tarefa';
if (labels.includes('bug'))            tipo = 'Bug';
if (labels.includes('documentação'))   tipo = 'Documentação';
if (labels.includes('melhoria') || labels.includes('feature') || labels.includes('enhancement')) {
  tipo = 'Melhoria';
}
if (labels.includes('refactor') || labels.includes('refatoração')) {
  tipo = 'Refatoração';
}

let status = 'Aberto';
if (issueState === 'closed') status = 'Concluído';
if (labels.includes('em andamento') || labels.includes('in progress')) status = 'Em Andamento';
if (labels.includes('não iniciado') || labels.includes('nao iniciado')) status = 'Não iniciado';

let milestone = 'Sem milestone';
if (issue.milestone?.title) {
  milestone = issue.milestone.title;
}

// ---------- RETORNO ----------
return {
  json: {
    unique_id:        uniqueId,

    issue_number:     issueNumber,
    issue_title:      issueTitle,
    issue_body:       issueBody,
    descricao:        descricao,

    issue_html_url:   issueUrl,
    issue_state:      issueState,
    issue_created_at: issueCreatedAt,
    issue_updated_at: issueUpdatedAt,

    repo_full_name:   repoFullName,
    repo_name:        repoName,

    all_labels:       labels,

    prioridade:       prioridade,
    projeto:          repoName,
    status:           status,
    tipo:             tipo,
    tipo_projeto:     tipoProjeto,
    milestone:        milestone,
  }
};
