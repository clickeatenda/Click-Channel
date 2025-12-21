/**
 * PARSER WEBHOOK CORRIGIDO - GitHub Issues para Notion
 * Detecta repositório REAL e gera uniq_id correto
 * 
 * Repositórios suportados (com auto-detecção):
 * - Click-Channel-Final (Mobile/Dart)
 * - ClickChannel (Mobile/Dart)
 * - clickflix (Mobile/Dart)
 * - Click-Studio (Frontend/TS)
 * - Click-Studio-DEMO (Frontend Demo)
 * - ld-land-page (Landing Page)
 * - v0-beauty-studio-dashboard (Dashboard)
 * - clickfinance (Finance App)
 * - clickeatenda-web (Web)
 */

return $input.all().map(item => {
  const issue = item.json;
  if (!issue.title) return { json: {} };

  const rawLabels = issue.labels || [];
  const labels = rawLabels.map(l => (l.name || '').toLowerCase());

  // ✅ CORRIGIDO: Detectar repositório de múltiplas fontes com prioridade
  let owner = issue.repository?.owner?.login || 'clickeatenda';
  let repoName = issue.repository?.name;
  
  // Se não tiver no objeto repository, tenta extrair da URL
  if (!repoName && issue.repository_url) {
    const urlMatch = issue.repository_url.match(/repos\/([^/]+)\/([^/]+)$/);
    if (urlMatch) {
      owner = urlMatch[1];
      repoName = urlMatch[2];
    }
  }
  
  // Se ainda não tiver, tenta da URL da issue (API v3)
  if (!repoName && issue.url) {
    const urlMatch = issue.url.match(/repos\/([^/]+)\/([^/]+)\/issues/);
    if (urlMatch) {
      owner = urlMatch[1];
      repoName = urlMatch[2];
    }
  }

  // Fallback final com aviso
  if (!repoName) {
    console.warn('⚠️ AVISO: Repositório não detectado, verifique o webhook');
    repoName = 'REPOSITORIO_NAO_DETECTADO';
  }

  const issueNum = issue.number || 0;
  const uniqueId = `${owner}/${repoName}#${issueNum}`; // ✅ CORRIGIDO

  // ✅ Auto-detecção de Tipo de Projeto conforme repositório REAL
  let projectType = "Documentação";
  const repoLower = repoName.toLowerCase();

  // Mobile Apps (Dart)
  if (repoLower.includes('channel')) {
    projectType = "Aplicação Mobile";
  } else if (repoLower.includes('clickflix')) {
    projectType = "Aplicação Mobile";
  }
  // Frontend (TypeScript/React)
  else if (repoLower.includes('studio')) {
    projectType = "Aplicação WEB";
  } else if (repoLower.includes('dashboard') || repoLower.includes('v0')) {
    projectType = "Aplicação WEB";
  }
  // Landing Pages
  else if (repoLower.includes('land-page') || repoLower.includes('landing')) {
    projectType = "Landing Page";
  }
  // Aplicações de Negócio
  else if (repoLower.includes('finance') || repoLower.includes('clickfinance')) {
    projectType = "Aplicação WEB";
  }
  // Web genérico
  else if (repoLower.includes('web') || repoLower.includes('clickeatenda-web')) {
    projectType = "Aplicação WEB";
  }

  // ✅ Mapeamento automático de Fase conforme tipo de repositório
  let faseDefaultMilestone = "Sem milestone";
  
  if (projectType === "Aplicação Mobile") {
    faseDefaultMilestone = "Fase 2: Funcionalidades Principais";
  } else if (projectType === "Aplicação WEB") {
    faseDefaultMilestone = "Fase 2: Funcionalidades Principais";
  } else if (projectType === "Landing Page") {
    faseDefaultMilestone = "Fase 2: Desenvolvimento";
  }

  // Milestone
  let milestone = issue.milestone?.title || faseDefaultMilestone;
  let statusMilestone = "📋 Backlog e Planejamento";
  
  // Mapear milestone do GitHub para status genérico
  if (milestone) {
    const milestoneLower = milestone.toLowerCase();
    
    if (milestoneLower.includes('backlog') || milestoneLower.includes('planejamento')) {
      statusMilestone = "📋 Backlog e Planejamento";
    } else if (milestoneLower.includes('sprint')) {
      statusMilestone = "🚀 Sprint Atual";
    } else if (milestoneLower.includes('desenvolvimento') || milestoneLower.includes('dev') || milestoneLower.includes('in progress')) {
      statusMilestone = "🔧 Em Desenvolvimento";
    } else if (milestoneLower.includes('teste') || milestoneLower.includes('qa') || milestoneLower.includes('quality') || milestoneLower.includes('testing')) {
      statusMilestone = "🧪 Testes e Garantia de Qualidade";
    } else if (milestoneLower.includes('pronto') || milestoneLower.includes('ready') || milestoneLower.includes('complete')) {
      statusMilestone = "✅ Pronto para Implantação";
    } else if (milestoneLower.includes('produção') || milestoneLower.includes('production') || milestoneLower.includes('prod')) {
      statusMilestone = "🚢 Produção";
    } else if (milestoneLower.includes('monitoramento') || milestoneLower.includes('feedback') || milestoneLower.includes('monitoring')) {
      statusMilestone = "📊 Monitoramento e Feedback";
    } else if (milestoneLower.includes('arquivado') || milestoneLower.includes('archived')) {
      statusMilestone = "⏸️ Arquivado";
    }
  }

  // Prioridade
  let prioridade = "🟡 Média";
  if (labels.includes("urgente") || labels.includes("urgency-critical")) {
    prioridade = "🔴 Urgente";
  } else if (labels.includes("alta") || labels.includes("high") || labels.includes("priority-high")) {
    prioridade = "🟠 Alta";
  } else if (labels.includes("baixa") || labels.includes("low") || labels.includes("priority-low")) {
    prioridade = "🔵 Baixa";
  }

  // Status
  let status = "Aberto";
  if (issue.state === "closed") {
    status = "Concluído";
  } else if (labels.includes("em-andamento") || labels.includes("em andamento") || labels.includes("in-progress")) {
    status = "Em Andamento";
  }

  // Tipo
  let tipo = "Tarefa";
  if (labels.includes("bug")) {
    tipo = "Bug";
  } else if (labels.includes("feature") || labels.includes("enhancement") || labels.includes("funcionalidade")) {
    tipo = "Funcionalidade";
  } else if (labels.includes("melhoria") || labels.includes("improvement")) {
    tipo = "Melhoria";
  } else if (labels.includes("refactor") || labels.includes("refatoração")) {
    tipo = "Refatoração";
  } else if (labels.includes("documentação") || labels.includes("docs")) {
    tipo = "Documentação";
  }

  return {
    json: {
      // ✅ CAMPOS CORRIGIDOS
      uniq_id: uniqueId,                          // Formato: clickeatenda/NomeRepositorio#123
      Nome: issue.title,
      Descrição: issue.body || "Sem descrição",
      "GitHub Link": issue.html_url,
      Labels: rawLabels.map(l => l.name).join(", "),
      Prioridade: prioridade,
      Projeto: repoName,                          // Nome real do repositório
      Repositório: repoName,                      // Nome real do repositório
      Status: status,
      "Status de Milestone": statusMilestone,     // Genérico (MACRO)
      "Fase de Milestone": milestone,             // Específico (MÉDIA)
      "Tipo de Projeto": projectType,             // Auto-detectado
      Tipo: tipo,
      Owner: owner                                // clickeatenda
    }
  };
});
