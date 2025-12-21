// ========================================
// PARSER 2 - WEBHOOK AUTOMATION (FINAL)
// ========================================
// Para: Webhook GitHub
// Nomes unificados com PARSER_GET_ISSUES_API

return $input.all().map(item => {
  const issue = item.json;
  if (!issue.title) return { json: {} };

  const rawLabels = issue.labels || [];
  const labels = rawLabels.map(l => (l.name || '').toLowerCase());

  // ✅ CORRIGIDO: Detectar repositório de múltiplas fontes
  let owner = issue.repository?.owner?.login || 'unknown';
  let repoName = issue.repository?.name;
  
  // Se não tiver no objeto repository, tenta extrair da URL
  if (!repoName && issue.repository_url) {
    const urlMatch = issue.repository_url.match(/repos\/([^\/]+)\/([^\/]+)/);
    if (urlMatch) {
      owner = urlMatch[1];
      repoName = urlMatch[2];
    }
  }
  
  // Se ainda não tiver, tenta da URL da issue
  if (!repoName && issue.url) {
    const urlMatch = issue.url.match(/repos\/([^\/]+)\/([^\/]+)/);
    if (urlMatch) {
      owner = urlMatch[1];
      repoName = urlMatch[2];
    }
  }

  // Se ainda não tiver, tenta da html_url
  if (!repoName && issue.html_url) {
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

  const issueNum = issue.number || 0;
  const uniqueId = `${owner}/${repoName}#${issueNum}`;

  // ✅ CORRIGIDO: Truncar descrição para max 2000 chars
  let descricaoBody = issue.body || '';
  if (descricaoBody && descricaoBody.length > 2000) {
    descricaoBody = descricaoBody.substring(0, 1997) + '...';
  }
  const descricao = descricaoBody || issue.title || "Sem descrição";

  // Detectar tipo de projeto conforme nome do repositório
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
  if (issue.state === "closed") status = "Concluído";
  else if (labels.includes("em-andamento") || labels.includes("em andamento")) status = "Em Andamento";
  else if (labels.includes("não iniciado") || labels.includes("nao iniciado")) status = "Não iniciado";

  // Tipo
  let tipo = "Tarefa";
  if (labels.includes("bug")) tipo = "Bug";
  else if (labels.includes("feature") || labels.includes("funcionalidade")) tipo = "Funcionalidade";
  else if (labels.includes("melhoria")) tipo = "Melhoria";
  else if (labels.includes("refactor") || labels.includes("refatoração")) tipo = "Refatoração";
  else if (labels.includes("documentação")) tipo = "Documentação";

  // ✅ CORRIGIDO: Milestone SEMPRE com valor
  let milestone = "Sem milestone";
  if (issue.milestone?.title) {
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
    return [];
  }

  staticData[cacheKey] = now;

  // ✅ NOMES UNIFICADOS COM GET ISSUES
  return {
    json: {
      unique_id:        uniqueId,
      issue_number:     issueNum,
      issue_title:      issue.title,
      issue_body:       descricaoBody,  // ✅ TRUNCADO
      descricao:        descricao,      // ✅ TRUNCADO
      issue_html_url:   issue.html_url || '',
      issue_state:      issue.state || 'open',
      issue_created_at: issue.created_at || new Date().toISOString(),
      issue_updated_at: issue.updated_at || new Date().toISOString(),
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
});
