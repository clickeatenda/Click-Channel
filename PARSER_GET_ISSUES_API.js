// ========================================
// PARSER 1 - GET ISSUES FROM API
// ========================================
// Para usar com node "Get issues of a repository"
// Importação manual de issues já criadas no GitHub

const issue = $input.item.json;

// Não temos 'repository' do webhook aqui,
// então tentamos extrair da URL da issue
let repoFullName = '';
let repoName = '';

// Extrai da html_url: https://github.com/owner/repo/issues/123
if (issue.html_url) {
  const urlMatch = issue.html_url.match(/github\.com\/([^\/]+)\/([^\/]+)\/issues/);
  if (urlMatch) {
    repoFullName = `${urlMatch[1]}/${urlMatch[2]}`;
    repoName = urlMatch[2];
  }
}

// Se não conseguiu, tenta da URL da API
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

// Labels - pode vir como array de objetos ou strings
const labels = (issue.labels || []).map(l => {
  if (typeof l === 'object' && l.name) {
    return l.name.toLowerCase();
  }
  return (l || '').toLowerCase();
});

// ✅ IMPORTANTE: Péga o título REAL da issue
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

// Descrição - trunca para 2000 chars
let issueBody = issue.body || '';
if (issueBody && issueBody.length > 2000) {
  issueBody = issueBody.substring(0, 1997) + '...';
}
const descricao = issueBody && issueBody.trim() ? issueBody.trim() : issueTitle;

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
