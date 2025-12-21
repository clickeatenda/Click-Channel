/**
 * PARSER WEBHOOK CORRIGIDO v3 - GitHub Issues para Notion
 * CORRIGE: Campo Descrição limitado a 2000 caracteres no Notion
 * 
 * Repositórios suportados:
 * - Click-Channel-Final, ClickChannel, clickflix (Mobile)
 * - Click-Studio, Click-Studio-DEMO, etc (Frontend)
 * - ld-land-page (Landing Page)
 * - clickfinance, clickeatenda-web (Web Apps)
 */

return $input.all().map(item => {
  const issue = item.json;
  if (!issue.title) return { json: {} };

  const rawLabels = issue.labels || [];
  const labels = rawLabels.map(l => (l.name || '').toLowerCase());

  // Detectar repositório
  let owner = issue.repository?.owner?.login || 'clickeatenda';
  let repoName = issue.repository?.name;
  
  if (!repoName && issue.repository_url) {
    const urlMatch = issue.repository_url.match(/repos\/([^\/]+)\/([^\/]+)$/);
    if (urlMatch) {
      owner = urlMatch[1];
      repoName = urlMatch[2];
    }
  }
  
  if (!repoName && issue.url) {
    const urlMatch = issue.url.match(/repos\/([^\/]+)\/([^\/]+)\/issues/);
    if (urlMatch) {
      owner = urlMatch[1];
      repoName = urlMatch[2];
    }
  }

  if (!repoName) {
    repoName = 'REPOSITORIO_NAO_DETECTADO';
  }

  const issueNum = issue.number || 0;
  const uniqueId = `${owner}/${repoName}#${issueNum}`;

  // ✅ CORRIGIDO: Truncar descrição para max 2000 caracteres
  let descricao = issue.body || "Sem descrição";
  if (descricao && descricao.length > 2000) {
    descricao = descricao.substring(0, 1997) + "...";
  }

  // Auto-detecção de Tipo de Projeto
  let projectType = "Documentação";
  const repoLower = repoName.toLowerCase();

  if (repoLower.includes('channel') || repoLower.includes('clickflix')) {
    projectType = "Aplicação Mobile";
  } else if (repoLower.includes('studio') || repoLower.includes('dashboard') || repoLower.includes('web') || repoLower.includes('finance')) {
    projectType = "Aplicação WEB";
  } else if (repoLower.includes('land-page')) {
    projectType = "Landing Page";
  }

  // Fase de Milestone
  let faseDefaultMilestone = "Sem milestone";
  if (projectType === "Aplicação Mobile" || projectType === "Aplicação WEB") {
    faseDefaultMilestone = "Fase 2: Funcionalidades Principais";
  } else if (projectType === "Landing Page") {
    faseDefaultMilestone = "Fase 2: Desenvolvimento";
  }

  let faseMilestone = issue.milestone?.title || faseDefaultMilestone;
  if (!faseMilestone) {
    faseMilestone = faseDefaultMilestone;
  }

  // Status de Milestone
  let statusMilestone = "📋 Backlog e Planejamento";
  
  if (faseMilestone && faseMilestone !== "Sem milestone") {
    const m = faseMilestone.toLowerCase();
    if (m.includes('sprint')) {
      statusMilestone = "🚀 Sprint Atual";
    } else if (m.includes('desenvolvimento') || m.includes('dev')) {
      statusMilestone = "🔧 Em Desenvolvimento";
    } else if (m.includes('teste') || m.includes('qa')) {
      statusMilestone = "🧪 Testes e Garantia de Qualidade";
    } else if (m.includes('pronto')) {
      statusMilestone = "✅ Pronto para Implantação";
    } else if (m.includes('produção')) {
      statusMilestone = "🚢 Produção";
    } else if (m.includes('monitoramento')) {
      statusMilestone = "📊 Monitoramento e Feedback";
    } else if (m.includes('arquivado')) {
      statusMilestone = "⏸️ Arquivado";
    }
  }

  // Prioridade
  let prioridade = "🟡 Média";
  if (labels.includes("urgente")) {
    prioridade = "🔴 Urgente";
  } else if (labels.includes("alta")) {
    prioridade = "🟠 Alta";
  } else if (labels.includes("baixa")) {
    prioridade = "🔵 Baixa";
  }

  // Status
  let status = "Aberto";
  if (issue.state === "closed") {
    status = "Concluído";
  } else if (labels.includes("em-andamento") || labels.includes("em andamento")) {
    status = "Em Andamento";
  }

  // Tipo
  let tipo = "Tarefa";
  if (labels.includes("bug")) {
    tipo = "Bug";
  } else if (labels.includes("feature") || labels.includes("funcionalidade")) {
    tipo = "Funcionalidade";
  } else if (labels.includes("melhoria")) {
    tipo = "Melhoria";
  } else if (labels.includes("refactor")) {
    tipo = "Refatoração";
  }

  // ✅ RETORNO FINAL - SEMPRE COM VALORES E DENTRO DOS LIMITES
  return {
    json: {
      "Nome": issue.title,
      "uniq_id": uniqueId,
      "Projeto": repoName,
      "Repositório": repoName,
      "Owner": owner,
      "Descrição": descricao,  // ✅ TRUNCADO a 2000 chars max
      "GitHub Link": issue.html_url,
      "Labels": rawLabels.map(l => l.name).join(", "),
      "Tipo de Projeto": projectType,
      "Tipo": tipo,
      "Status": status,
      "Prioridade": prioridade,
      "Status de Milestone": statusMilestone || "📋 Backlog e Planejamento",
      "Fase de Milestone": faseMilestone || "Sem milestone",
      "Data de Atualização": issue.updated_at || new Date().toISOString()
    }
  };
});
