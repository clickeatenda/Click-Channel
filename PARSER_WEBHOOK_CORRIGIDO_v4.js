// ---------- PARSE GITHUB ISSUE WEBHOOK ----------
// ✅ V4 - CORRIGIDO para Notion
// - issue_title SEMPRE com valor (nunca undefined)
// - Detecta repositório real
// - Trunca descrição para max 2000 chars

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

// Agora raw deve ser o JSON do GitHub
const issue = raw.issue || {};
const repo  = raw.repository || {};

// ✅ CORRIGIDO: Detectar repositório de múltiplas fontes
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

// Fallback final
if (!repoName) {
  repoFullName = 'unknown/REPOSITORIO_NAO_DETECTADO';
  repoName = 'REPOSITORIO_NAO_DETECTADO';
}

// Labels normalizadas para minúsculo
const labels = (issue.labels || []).map(l => (l.name || '').toLowerCase());

// ✅ CORRIGIDO: issue_title NUNCA undefined
const issueNumber    = issue.number || 0;
const issueTitle     = issue.title && issue.title.trim() ? issue.title : `Issue #${issueNumber}`;
const issueUrl       = issue.html_url || '';
const issueState     = issue.state || 'open';
const issueCreatedAt = issue.created_at || new Date().toISOString();
const issueUpdatedAt = issue.updated_at || new Date().toISOString();
const uniqueId       = `${repoFullName}#${issueNumber}`;

// ✅ CORRIGIDO: Truncar descrição para max 2000 chars (limite Notion)
let issueBody = issue.body || '';
if (issueBody && issueBody.length > 2000) {
  issueBody = issueBody.substring(0, 1997) + '...';
}

// Descrição para Notion (truncada e garantida)
const descricao = issueBody || issueTitle || 'Sem descrição';

// ---------- ANTI-LOOP (opcional, pode remover se não quiser) ----------
const cacheKey   = `issue_${uniqueId}`;
const now        = Date.now();
const staticData = $getWorkflowStaticData('global');
const lastRun    = staticData[cacheKey];

if (lastRun && (now - lastRun) < 2 * 60 * 1000) {
  // Se essa mesma issue passou pelo fluxo há menos de 2 minutos,
  // não envia nada pra frente (evita duplicação/loop).
  return [];
}

// Atualiza o cache com o horário atual
staticData[cacheKey] = now;

// ---------- DERIVAÇÕES EM PT-BR ----------

// Prioridade em PT-BR (Alta, Média, Baixa)
let prioridade = 'Média';
if (labels.includes('alta'))  prioridade = 'Alta';
if (labels.includes('baixa')) prioridade = 'Baixa';

// ✅ CORRIGIDO: Auto-detectar baseado no nome do repositório
let tipoProjeto = 'Desconhecido';
const repoLower = repoName.toLowerCase();
if (repoLower.includes('channel') || repoLower.includes('clickflix')) {
  tipoProjeto = 'Aplicação Mobile';
} else if (repoLower.includes('studio') || repoLower.includes('dashboard') || repoLower.includes('web') || repoLower.includes('finance')) {
  tipoProjeto = 'Aplicação WEB';
} else if (repoLower.includes('land-page') || repoLower.includes('landing')) {
  tipoProjeto = 'Landing Page';
} else {
  // Fallback: tenta detectar por labels
  const tiposConhecidos = [
    'aplicação web',
    'mobile',
    'api',
    'backend',
    'frontend',
    'infraestrutura',
  ];
  const foundTipo = labels.find(l => tiposConhecidos.includes(l));
  if (foundTipo === 'aplicação web') {
    tipoProjeto = 'Aplicação WEB';
  } else if (foundTipo) {
    tipoProjeto = foundTipo.charAt(0).toUpperCase() + foundTipo.slice(1);
  }
}

// Tipo (Bug / Tarefa / Melhoria / Documentação)
let tipo = 'Tarefa';
if (labels.includes('bug'))            tipo = 'Bug';
if (labels.includes('documentação'))   tipo = 'Documentação';
if (labels.includes('melhoria') || labels.includes('feature') || labels.includes('enhancement')) {
  tipo = 'Melhoria';
}

// Status em PT-BR
let status = 'Aberto';
if (issueState === 'closed') status = 'Concluído';
if (labels.includes('em andamento') || labels.includes('in progress')) status = 'Em Andamento';
if (labels.includes('não iniciado') || labels.includes('nao iniciado')) status = 'Não iniciado';

// ✅ CORRIGIDO: Milestone SEMPRE com valor (nunca undefined)
let milestone = 'Sem milestone';
if (issue.milestone?.title) {
  milestone = issue.milestone.title;
}

// ---------- RETORNO ÚNICO PARA OS PRÓXIMOS NODES ----------
// ✅ MANTM NOMES ORIGINAIS + CORRIGIDO PARA NOTION
return {
  json: {
    unique_id:        uniqueId,

    issue_number:     issueNumber,
    issue_title:      issueTitle,     // ✅ GARANTIDO - nunca undefined
    issue_body:       issueBody,      // ✅ TRUNCADO
    descricao:        descricao,      // ✅ TRUNCADO E GARANTIDO

    issue_html_url:   issueUrl,
    issue_state:      issueState,
    issue_created_at: issueCreatedAt,
    issue_updated_at: issueUpdatedAt,

    repo_full_name:   repoFullName,   // ✅ DETECTADO CORRETAMENTE
    repo_name:        repoName,       // ✅ DETECTADO CORRETAMENTE

    all_labels:       labels,         // array em minúsculo

    prioridade:       prioridade,     // Alta / Média / Baixa
    projeto:          repoName,       // ✅ Nome real do repositório
    status:           status,         // Aberto / Em Andamento / Não iniciado / Concluído
    tipo:             tipo,           // Tarefa / Bug / Melhoria / Documentação
    tipo_projeto:     tipoProjeto,    // ✅ AUTO-DETECTADO POR REPOSITÓRIO
    milestone:        milestone,      // ✅ SEMPRE COM VALOR
  }
};
