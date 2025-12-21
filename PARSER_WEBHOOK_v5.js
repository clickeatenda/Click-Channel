// ---------- PARSE GITHUB ISSUE WEBHOOK ou API RESPONSE ----------
// ✅ V5 - Funciona com WEBHOOK + LIST API
// - Detecta se é webhook ou API list
// - Pega título corretamente
// - Detecta repositório real
// - Trunca descrição para max 2000 chars

// Entrada bruta - pode ser webhook ou API list
let raw = $input.item.json;

// Tentar parsear se for string
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

// Se for webhook do GitHub, tem 'issue' e 'repository'
// Se for API list, vem direto o issue object
const issue = raw.issue || raw;
const repo  = raw.repository || {};

// ✅ CORRIGIDO: Detectar repositório de múltiplas fontes
let repoFullName = repo.full_name || '';
let repoName = repo.name || '';

// Se não tiver repositório do webhook, tenta extrair da URL
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

// Labels normalizadas para minúsculo
const labels = (issue.labels || []).map(l => {
  // Se for objeto com 'name'
  if (typeof l === 'object' && l.name) {
    return l.name.toLowerCase();
  }
  // Se for string direto
  return (l || '').toLowerCase();
});

// ✅ CORRIGIDO: Péga o título CORRETAMENTE
const issueNumber = issue.number || 0;
const issueTitle = (issue.title && issue.title.trim()) ? issue.title.trim() : '';
const issueUrl   = issue.html_url || '';
const issueState = issue.state || 'open';
const issueCreatedAt = issue.created_at || new Date().toISOString();
const issueUpdatedAt = issue.updated_at || new Date().toISOString();
const uniqueId = `${repoFullName}#${issueNumber}`;

// Validação final do título
if (!issueTitle) {
  // Se não tiver título, retorna vazio (não Issue #0)
  return { json: {} };
}

// ✅ CORRIGIDO: Truncar descrição para max 2000 chars
let issueBody = issue.body || '';
if (issueBody && issueBody.length > 2000) {
  issueBody = issueBody.substring(0, 1997) + '...';
}

// Descrição para Notion (truncada e garantida)
const descricao = issueBody && issueBody.trim() ? issueBody.trim() : issueTitle;

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

// Prioridade em PT-BR
let prioridade = 'Média';
if (labels.includes('alta'))  prioridade = 'Alta';
if (labels.includes('urgente')) prioridade = 'Urgente';
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
} else if (repoLower.includes('backend') || repoLower.includes('api')) {
  tipoProjeto = 'Backend / API';
} else if (repoLower.includes('infra') || repoLower.includes('devops')) {
  tipoProjeto = 'Infraestrutura';
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
if (labels.includes('refactor') || labels.includes('refatoração')) {
  tipo = 'Refatoração';
}

// Status em PT-BR
let status = 'Aberto';
if (issueState === 'closed') status = 'Concluído';
if (labels.includes('em andamento') || labels.includes('in progress')) status = 'Em Andamento';
if (labels.includes('não iniciado') || labels.includes('nao iniciado')) status = 'Não iniciado';

// ✅ CORRIGIDO: Milestone SEMPRE com valor
let milestone = 'Sem milestone';
if (issue.milestone?.title) {
  milestone = issue.milestone.title;
}

// ---------- RETORNO ÚNICO PARA OS PRÓXIMOS NODES ----------
return {
  json: {
    unique_id:        uniqueId,

    issue_number:     issueNumber,
    issue_title:      issueTitle,     // ✅ GARANTIDO - do issue.title real
    issue_body:       issueBody,      // ✅ TRUNCADO
    descricao:        descricao,      // ✅ TRUNCADO E GARANTIDO

    issue_html_url:   issueUrl,
    issue_state:      issueState,
    issue_created_at: issueCreatedAt,
    issue_updated_at: issueUpdatedAt,

    repo_full_name:   repoFullName,   // ✅ DETECTADO CORRETAMENTE
    repo_name:        repoName,       // ✅ DETECTADO CORRETAMENTE

    all_labels:       labels,         // array em minúsculo

    prioridade:       prioridade,     // Alta / Média / Baixa / Urgente
    projeto:          repoName,       // ✅ Nome real do repositório
    status:           status,         // Aberto / Em Andamento / Não iniciado / Concluído
    tipo:             tipo,           // Tarefa / Bug / Melhoria / Documentação / Refatoração
    tipo_projeto:     tipoProjeto,    // ✅ AUTO-DETECTADO POR REPOSITÓRIO
    milestone:        milestone,      // ✅ SEMPRE COM VALOR
  }
};
