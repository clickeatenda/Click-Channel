/**
 * PARSER WEBHOOK CORRIGIDO v2 - GitHub Issues para Notion
 * CORRIGE: Campo Milestone deve ter valor sempre (nunca undefined)
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

  // ✅ Detectar repositório de múltiplas fontes
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

  // ✅ IMPORTANTE: Sempre retornar valor (nunca undefined)
  let faseDefaultMilestone = "Sem milestone";
  if (projectType === "Aplicação Mobile" || projectType === "Aplicação WEB") {
    faseDefaultMilestone = "Fase 2: Funcionalidades Principais";
  } else if (projectType === "Landing Page") {
    faseDefaultMilestone = "Fase 2: Desenvolvimento";
  }

  // ✅ Milestone NUNCA pode ser undefined
  let faseeMilestone = issue.milestone?.title || faseDefaultMilestone;
  
  // Validação: se ainda for null/undefined, força valor
  if (!faseeMilestone) {
    faseeMilestone = faseDefaultMilestone;
  }

  // Status de Milestone
  let statusMilestone = "📋 Backlog e Planejamento";
  
  if (faseeMilestone && faseeMilestone !== "Sem milestone") {
    const m = faseeMilestone.toLowerCase();
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
  if (labels.includes("urgente")) prioridade = "🔴 Urgente";
  else if (labels.includes("alta")) prioridade = "🟠 Alta";
  else if (labels.includes("baixa")) prioridade = "🔵 Baixa";

  // Status
  let status = "Aberto";
  if (issue.state === "closed") status = "Concluído";
  else if (labels.includes("em-andamento") || labels.includes("em andamento")) status = "Em Andamento";

  // Tipo
  let tipo = "Tarefa";
  if (labels.includes("bug")) tipo = "Bug";
  else if (labels.includes("feature") || labels.includes("funcionalidade")) tipo = "Funcionalidade";
  else if (labels.includes("melhoria")) tipo = "Melhoria";
  else if (labels.includes("refactor")) tipo = "Refatoração";

  // ✅ MAPEAMENTO EXATO DOS CAMPOS DO NOTION
  // Certifique-se que os nomes aqui correspondem exatamente aos do seu banco Notion
  return {
    json: {
      // Campo de Título (obrigatório)
      "Nome": issue.title,
      
      // Chaves do repositório
      "uniq_id": uniqueId,
      "Projeto": repoName,
      "Repositório": repoName,
      "Owner": owner,
      
      // Conteúdo
      "Descrição": issue.body || "Sem descrição",
      "GitHub Link": issue.html_url,
      "Labels": rawLabels.map(l => l.name).join(", "),
      
      // Classificação
      "Tipo de Projeto": projectType,
      "Tipo": tipo,
      "Status": status,
      "Prioridade": prioridade,
      
      // ✅ MILESTONES - NUNCA UNDEFINED
      "Status de Milestone": statusMilestone || "📋 Backlog e Planejamento",
      "Fase de Milestone": faseeMilestone || "Sem milestone",
      
      // Se seu Notion tem campo "Milestone" simples (não Status + Fase separados):
      // Descomente a linha abaixo:
      // "Milestone": faseeMilestone || "Sem milestone",
      
      // Campos adicionais úteis
      "Data de Atualização": issue.updated_at || new Date().toISOString(),
      "Estado do GitHub": issue.state || "unknown"
    }
  };
});
