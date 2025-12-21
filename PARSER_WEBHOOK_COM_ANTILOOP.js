// ========================================
// PARSER WEBHOOK - COM ANTI-LOOP MELHORADO
// ========================================
// Evita duplicatas quando GitHub dispara 2x

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
const repo = raw.repository || {};

// Valores base com proteção
const repoFullName = repo.full_name || 'unknown/repo';
const repoName = repo.name || 'unknown';
const issueNumber = issue.number || 0;
const issueTitle = issue.title || 'Sem título';
const uniqueId = `${repoFullName}#${issueNumber}`;

// ✅ ANTI-LOOP - IMPORTANTE!
// GitHub dispara webhook 2x para a mesma ação
// Ignorar se processar 2x em menos de 15 segundos
const cacheKey = `issue_webhook_${uniqueId}`;
const now = Date.now();
const staticData = $getWorkflowStaticData('global');
const lastRun = staticData[cacheKey];

// ✅ Se processou há menos de 15 segundos, PULA COMPLETAMENTE
if (lastRun && (now - lastRun) < 15 * 1000) {
  console.log(`⚠️ ANTI-LOOP: Issue ${uniqueId} já processada há ${Math.round((now - lastRun) / 1000)}s - IGNORANDO`);
  return [];
}

// Atualiza cache com timestamp AGORA
staticData[cacheKey] = now;
console.log(`✅ PROCESSANDO: ${uniqueId} - timestamp: ${now}`);

// Labels normalizadas para minúsculo
const labels = (issue.labels || []).map(l => (l.name || '').toLowerCase());

let issueBody = issue.body || '';
const issueUrl = issue.html_url || '';
const issueState = issue.state || 'open';
const issueCreatedAt = issue.created_at || new Date().toISOString();
const issueUpdatedAt = issue.updated_at || new Date().toISOString();

// ✅ TRUNCAR DESCRIÇÃO PARA 2000 CHARS
if (issueBody && issueBody.length > 2000) {
  issueBody = issueBody.substring(0, 1997) + '...';
}
const descricao = issueBody || issueTitle;

// ---------- DERIVAÇÕES EM PT-BR ----------

// Prioridade
let prioridade = '🟡 Média';
if (labels.includes('urgente')) prioridade = '🔴 Urgente';
else if (labels.includes('alta')) prioridade = '🟠 Alta';
else if (labels.includes('baixa')) prioridade = '🔵 Baixa';

// Tipo de Projeto - AUTO-DETECTADO por nome do repo
let tipo_projeto = 'Desconhecido';
const repoLower = repoName.toLowerCase();

if (repoLower.includes('backend') || repoLower.includes('api')) {
  tipo_projeto = 'Backend / API';
} else if (repoLower.includes('channel') || repoLower.includes('clickflix')) {
  tipo_projeto = 'Aplicação Mobile';
} else if (repoLower.includes('infra') || repoLower.includes('devops')) {
  tipo_projeto = 'Infraestrutura';
} else if (repoLower.includes('analytics') || repoLower.includes('data')) {
  tipo_projeto = 'Dados / Analytics';
} else if (repoLower.includes('web') || repoLower.includes('frontend') || repoLower.includes('studio') || repoLower.includes('dashboard')) {
  tipo_projeto = 'Aplicação WEB';
} else if (repoLower.includes('land-page') || repoLower.includes('landing')) {
  tipo_projeto = 'Landing Page';
} else {
  const tiposConhecidos = [
    'aplicação web',
    'aplicaçao web',
    'mobile',
    'api',
    'backend',
    'frontend',
    'infraestrutura',
  ];
  const foundTipo = labels.find(l => tiposConhecidos.includes(l));
  if (foundTipo === 'aplicação web' || foundTipo === 'aplicaçao web') {
    tipo_projeto = 'Aplicação WEB';
  } else if (foundTipo) {
    tipo_projeto = foundTipo.charAt(0).toUpperCase() + foundTipo.slice(1);
  }
}

// Tipo (Bug / Tarefa / Melhoria / Documentação)
let tipo = 'Tarefa';
if (labels.includes('bug')) tipo = 'Bug';
if (labels.includes('documentação')) tipo = 'Documentação';
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

// Milestone
let milestone = 'Sem milestone';
if (issue.milestone?.title) milestone = issue.milestone.title;

let statusMilestone = '📋 Backlog e Planejamento';
if (milestone && milestone !== 'Sem milestone') {
  const m = milestone.toLowerCase();
  if (m.includes('sprint')) statusMilestone = '🚀 Sprint Atual';
  else if (m.includes('desenvolvimento') || m.includes('dev')) statusMilestone = '🔧 Em Desenvolvimento';
  else if (m.includes('teste') || m.includes('qa')) statusMilestone = '🧪 Testes e Garantia de Qualidade';
  else if (m.includes('pronto')) statusMilestone = '✅ Pronto para Implantação';
  else if (m.includes('produção')) statusMilestone = '🚢 Produção';
  else if (m.includes('monitoramento')) statusMilestone = '📊 Monitoramento e Feedback';
  else if (m.includes('arquivado')) statusMilestone = '⏸️ Arquivado';
}

// ---------- RETORNO Único PARA OS PRÓXIMOS NODES ----------
return {
  json: {
    unique_id:        uniqueId,
    
    issue_number:     issueNumber,
    issue_title:      issueTitle,
    issue_body:       issueBody,      // ✅ TRUNCADO
    descricao:        descricao,      // ✅ TRUNCADO
    
    issue_html_url:   issueUrl,
    issue_state:      issueState,
    issue_created_at: issueCreatedAt,
    issue_updated_at: issueUpdatedAt,
    
    repo_full_name:   repoFullName,
    repo_name:        repoName,
    
    all_labels:       labels,
    
    prioridade:       prioridade,     // Com emoji
    projeto:          repoName,
    status:           status,
    tipo:             tipo,
    tipo_projeto:     tipo_projeto,   // ✅ AUTO-DETECTADO
    milestone:        milestone,      // ✅ SEMPRE COM VALOR
    statusMilestone:  statusMilestone
  }
};
