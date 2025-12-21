// ========================================
// PARSER WEBHOOK N8N (FINAL)
// ========================================
// Para: Webhook GitHub no n8n
// Suporta múltiplos formatos de entrada

// ✅ Suportar múltiplas formas de entrada no n8n
let raw = $input.item.json;

// Se vier em body (string)
if (raw.body) {
  try {
    raw = typeof raw.body === 'string' ? JSON.parse(raw.body) : raw.body;
  } catch (e) {
    // Se não conseguir parsear, continua
  }
}

// Se vier em payload
if (raw.payload) {
  try {
    raw = typeof raw.payload === 'string' ? JSON.parse(raw.payload) : raw.payload;
  } catch (e) {
    // Se não conseguir parsear, continua
  }
}

// Webhook tem 'issue' e 'repository'
const issue = raw.issue || raw; // ✅ Se não tiver 'issue', trata raw como issue
const repo  = raw.repository || {};

// ✅ CORRIGIDO: Detectar repositório de múltiplas fontes
let owner = repo?.owner?.login || issue?.repository?.owner?.login || 'unknown';
let repoName = repo?.name || issue?.repository?.name;

// Se não tiver repositório, tenta extrair da URL
if (!repoName && issue?.repository_url) {
  const urlMatch = issue.repository_url.match(/repos\/([^\/]+)\/([^\/]+)/);
  if (urlMatch) {
    owner = urlMatch[1];
    repoName = urlMatch[2];
  }
}

// Se ainda não tiver, tenta da URL da issue
if (!repoName && issue?.url) {
  const urlMatch = issue.url.match(/repos\/([^\/]+)\/([^\/]+)/);
  if (urlMatch) {
    owner = urlMatch[1];
    repoName = urlMatch[2];
  }
}

// Se ainda não tiver, tenta da html_url
if (!repoName && issue?.html_url) {
  const urlMatch = issue.html_url.match(/github\.com\/([^\/]+)\/([^\/]+)\/issues/);
  if (urlMatch) {
    owner = urlMatch[1];
    repoName = urlMatch[2];
  }
}

// Fallback final
if (!repoName) {
  owner = 'unknown';
  repoName = 'REPOSITORIO_NAO_DETECTADO';
}

// ✅ CORRIGIDO: Título pode vir de várias formas
const issueTitle = issue?.title || issue?.name || '';

// ✅ IMPORTANTE: Se não tiver título, retorna vazio
if (!issueTitle || !issueTitle.trim()) {
  console.log('⚠️ AVISO: Issue sem título. Data recebida:', JSON.stringify(raw));
  return { json: {} };
}

const issueNum = issue?.number || 0;
const uniqueId = `${owner}/${repoName}#${issueNum}`;

// Labels - pode vir como array de objetos ou strings
const rawLabels = issue?.labels || [];
const labels = rawLabels.map(l => {
  if (typeof l === 'object' && l.name) {
    return l.name.toLowerCase();
  }
  return (l || '').toLowerCase();
});

// ✅ CORRIGIDO: Truncar descrição para 2000 chars
let descricaoBody = issue?.body || '';
if (descricaoBody && descricaoBody.length > 2000) {
  descricaoBody = descricaoBody.substring(0, 1997) + '...';
}
const descricao = descricaoBody && descricaoBody.trim() ? descricaoBody.trim() : issueTitle;

// Detectar tipo de projeto
let tipo_projeto = "Documentação";
const repoLower = repoName.toLowerCase();

if (repoLower.includes('backend') || repoLower.includes('api')) {
  tipo_projeto = "Backend / API";
} else if (repoLower.includes('channel') || repoLower.includes('clickflix')) {
  tipo_projeto = "Aplicação Mobile";
} else if (repoLower.includes('infra') || repoLower.includes('devops')) {
  tipo_projeto = "Infraestrutura";
} else if (repoLower.includes('analytics') || repoLower.includes('data')) {
  tipo_projeto = "Dados / Analytics";
} else if (repoLower.includes('web') || repoLower.includes('frontend') || repoLower.includes('studio') || repoLower.includes('dashboard')) {
  tipo_projeto = "Aplicação WEB";
} else if (repoLower.includes('land-page') || repoLower.includes('landing')) {
  tipo_projeto = "Landing Page";
}

// Prioridade
let prioridade = "🟡 Média";
if (labels.includes("urgente")) prioridade = "🔴 Urgente";
else if (labels.includes("alta")) prioridade = "🟠 Alta";
else if (labels.includes("baixa")) prioridade = "🔵 Baixa";

// Status
let status = "Aberto";
const issueState = issue?.state || 'open';
if (issueState === "closed") status = "Concluído";
else if (labels.includes("em-andamento") || labels.includes("em andamento")) status = "Em Andamento";
else if (labels.includes("não iniciado") || labels.includes("nao iniciado")) status = "Não iniciado";

// Tipo
let tipo = "Tarefa";
if (labels.includes("bug")) tipo = "Bug";
else if (labels.includes("feature") || labels.includes("funcionalidade")) tipo = "Funcionalidade";
else if (labels.includes("melhoria")) tipo = "Melhoria";
else if (labels.includes("refactor") || labels.includes("refatoração")) tipo = "Refatoração";
else if (labels.includes("documentação")) tipo = "Documentação";

// Milestone
let milestone = "Sem milestone";
if (issue?.milestone?.title) {
  milestone = issue.milestone.title;
}

let statusMilestone = "📋 Backlog e Planejamento";

if (milestone && milestone !== "Sem milestone") {
  const m = milestone.toLowerCase();
  if (m.includes('sprint')) statusMilestone = "🚀 Sprint Atual";
  else if (m.includes('desenvolvimento') || m.includes('dev')) statusMilestone = "🔧 Em Desenvolvimento";
  else if (m.includes('teste') || m.includes('qa')) statusMilestone = "🧪 Testes e Garantia de Qualidade";
  else if (m.includes('pronto')) statusMilestone = "✅ Pronto para Implantação";
  else if (m.includes('produção')) statusMilestone = "🚢 Produção";
  else if (m.includes('monitoramento')) statusMilestone = "📊 Monitoramento e Feedback";
  else if (m.includes('arquivado')) statusMilestone = "⏸️ Arquivado";
}

// ✅ ANTI-LOOP (IMPORTANTE para webhook)
const cacheKey   = `webhook_${uniqueId}`;
const now        = Date.now();
const staticData = $getWorkflowStaticData('global');
const lastRun    = staticData[cacheKey];

if (lastRun && (now - lastRun) < 5 * 1000) {
  console.log('⚠️ ANTI-LOOP: Issue processada há menos de 5 segundos');
  return [];
}

staticData[cacheKey] = now;

// ✅ RETORNO FINAL
const output = {
  json: {
    unique_id:        uniqueId,
    issue_number:     issueNum,
    issue_title:      issueTitle,
    issue_body:       descricaoBody,
    descricao:        descricao,
    issue_html_url:   issue?.html_url || '',
    issue_state:      issueState,
    issue_created_at: issue?.created_at || new Date().toISOString(),
    issue_updated_at: issue?.updated_at || new Date().toISOString(),
    repo_full_name:   `${owner}/${repoName}`,
    repo_name:        repoName,
    all_labels:       labels,
    prioridade:       prioridade,
    projeto:          repoName,
    status:           status,
    tipo:             tipo,
    tipo_projeto:     tipo_projeto,
    milestone:        milestone,
    statusMilestone:  statusMilestone
  }
};

console.log('✅ Parser executado com sucesso:', output.json.unique_id);
return output;
