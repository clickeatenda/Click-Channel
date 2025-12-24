#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de Análise Estática do Click Channel
Detecta URLs hardcoded, dados pré-gravados, problemas de segurança
"""

import os
import re
import json
from pathlib import Path
from datetime import datetime

class APKAnalyzer:
    def __init__(self, project_root):
        self.project_root = Path(project_root)
        self.lib_path = self.project_root / 'lib'
        self.issues = {
            'urls_hardcoded': [],
            'dados_sensveis': [],
            'env_leak': [],
            'cache_issues': [],
            'config_issues': [],
            'security_issues': []
        }
        self.patterns = {
            'url': r'https?://[^\s\'"<>)}\]]+',
            'api_key': r'(api[_-]?key|apikey|secret|token|password)\s*[:=]\s*["\']?([^"\'<>\s]+)',
            'hardcoded_playlist': r'(playlist|m3u|epg).*?=.*?https?',
            'hardcoded_config': r'(const|static)\s+\w+.*?playlist|epg|url',
        }
        
    def analyze_dart_files(self):
        """Analisa todos os arquivos Dart"""
        print("🔍 Analisando arquivos Dart...")
        dart_files = list(self.lib_path.rglob('*.dart'))
        print(f"   Encontrados {len(dart_files)} arquivos Dart\n")
        
        for dart_file in dart_files:
            self.analyze_file(dart_file)
    
    def analyze_file(self, filepath):
        """Analisa um arquivo individual"""
        try:
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            relative_path = filepath.relative_to(self.project_root)
            
            # Buscar URLs
            urls = re.findall(self.patterns['url'], content)
            if urls:
                for url in urls:
                    # Filtrar URLs do Flutter SDK, pub.dev, GitHub
                    if not any(x in url for x in ['flutter.io', 'pub.dev', 'github.com/flutter', 'fonts.googleapis.com', 'api.github.com', 'raw.githubusercontent.com']):
                        self.issues['urls_hardcoded'].append({
                            'file': str(relative_path),
                            'url': url,
                            'severity': 'HIGH' if 'playlist' in content.lower() or 'epg' in content.lower() else 'MEDIUM'
                        })
            
            # Buscar credenciais/tokens
            credentials = re.findall(self.patterns['api_key'], content, re.IGNORECASE)
            if credentials:
                for cred in credentials:
                    # Filtrar valores seguros como 'null', 'true', 'false'
                    if cred[1].lower() not in ['null', 'true', 'false', '']:
                        self.issues['dados_sensveis'].append({
                            'file': str(relative_path),
                            'type': cred[0],
                            'value': f"{cred[1][:20]}..." if len(cred[1]) > 20 else cred[1],
                            'severity': 'CRITICAL'
                        })
            
            # Procurar por .env
            if '.env' in content and ('load' in content.lower() or 'dotenv' in content.lower()):
                self.issues['env_leak'].append({
                    'file': str(relative_path),
                    'type': '.env loading',
                    'severity': 'HIGH'
                })
            
            # Procurar por cache hardcoded
            if 'clearAllCache' in content or 'clearMemoryCache' in content:
                self.issues['cache_issues'].append({
                    'file': str(relative_path),
                    'type': 'Cache management found',
                    'severity': 'INFO'
                })
            
            # Procurar por configurações hardcoded
            if re.search(r'const.*?(playlist|epg|url).*?=', content, re.IGNORECASE):
                self.issues['config_issues'].append({
                    'file': str(relative_path),
                    'type': 'Hardcoded config found',
                    'severity': 'WARNING'
                })
        
        except Exception as e:
            print(f"   ⚠️  Erro ao analisar {filepath}: {e}")
    
    def check_env_file(self):
        """Verifica arquivo .env"""
        env_file = self.project_root / '.env'
        if env_file.exists():
            print("\n⚠️  AVISO: Arquivo .env encontrado!")
            try:
                with open(env_file, 'r', encoding='utf-8') as f:
                    env_content = f.read()
                
                # Detectar credenciais
                for line in env_content.split('\n'):
                    if line and not line.startswith('#'):
                        self.issues['env_leak'].append({
                            'file': '.env',
                            'content': line.split('=')[0] if '=' in line else line,
                            'severity': 'CRITICAL'
                        })
            except Exception as e:
                print(f"   Erro ao ler .env: {e}")
    
    def check_pubspec(self):
        """Verifica pubspec.yaml"""
        pubspec_file = self.project_root / 'pubspec.yaml'
        if pubspec_file.exists():
            print("\n📦 Analisando pubspec.yaml...")
            with open(pubspec_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Verificar por dependências sensíveis
            if 'flutter_dotenv' in content:
                self.issues['security_issues'].append({
                    'file': 'pubspec.yaml',
                    'issue': 'flutter_dotenv loaded - .env pode conter credenciais',
                    'severity': 'MEDIUM',
                    'recommendation': 'Usar flutter_secure_storage para produção'
                })
    
    def analyze_config_files(self):
        """Analisa arquivos de configuração"""
        print("\n🔧 Analisando arquivos de configuração...")
        
        # Procurar por config.dart
        config_file = self.lib_path / 'core' / 'config.dart'
        if config_file.exists():
            with open(config_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Buscar URLs hardcoded
            urls = re.findall(self.patterns['url'], content)
            if urls:
                self.issues['config_issues'].append({
                    'file': 'lib/core/config.dart',
                    'type': 'URLs found in config',
                    'count': len(urls),
                    'severity': 'HIGH'
                })
    
    def generate_report(self):
        """Gera relatório de análise"""
        print("\n" + "="*70)
        print("📊 RELATÓRIO DE ANÁLISE - CLICK CHANNEL")
        print("="*70)
        print(f"Data: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Projeto: {self.project_root.name}")
        print("="*70 + "\n")
        
        # URLs Hardcoded
        if self.issues['urls_hardcoded']:
            print("🔴 URLs HARDCODED DETECTADAS:")
            for issue in self.issues['urls_hardcoded']:
                print(f"   ❌ {issue['file']}")
                print(f"      URL: {issue['url'][:60]}...")
                print(f"      Severidade: {issue['severity']}\n")
        else:
            print("✅ NENHUMA URL HARDCODED DETECTADA\n")
        
        # Dados Sensíveis
        if self.issues['dados_sensveis']:
            print("🔴 DADOS SENSÍVEIS DETECTADOS:")
            for issue in self.issues['dados_sensveis']:
                print(f"   ❌ {issue['file']}")
                print(f"      Tipo: {issue['type']}")
                print(f"      Valor: {issue['value']}")
                print(f"      Severidade: {issue['severity']}\n")
        else:
            print("✅ NENHUM DADO SENSÍVEL DETECTADO\n")
        
        # .env Leak
        if self.issues['env_leak']:
            print("🟡 PROBLEMAS COM .env:")
            for issue in self.issues['env_leak']:
                print(f"   ⚠️  {issue['file']}")
                if 'content' in issue:
                    print(f"      Chave: {issue['content']}")
                print(f"      Severidade: {issue['severity']}\n")
        else:
            print("✅ NENHUM PROBLEMA DE .env DETECTADO\n")
        
        # Cache Issues
        if self.issues['cache_issues']:
            print("ℹ️  GERENCIAMENTO DE CACHE DETECTADO:")
            for issue in self.issues['cache_issues'][:5]:  # Mostrar primeiros 5
                print(f"   ℹ️  {issue['file']}")
                print(f"      {issue['type']}\n")
        
        # Security Issues
        if self.issues['security_issues']:
            print("🔒 PROBLEMAS DE SEGURANÇA:")
            for issue in self.issues['security_issues']:
                print(f"   {issue['file']}")
                print(f"      ⚠️  {issue['issue']}")
                print(f"      💡 {issue['recommendation']}\n")
        
        # Resumo
        print("="*70)
        print("📋 RESUMO")
        print("="*70)
        
        total_issues = (len(self.issues['urls_hardcoded']) + 
                       len(self.issues['dados_sensveis']) + 
                       len(self.issues['env_leak']) +
                       len(self.issues['security_issues']))
        
        print(f"URLs Hardcoded: {len(self.issues['urls_hardcoded'])}")
        print(f"Dados Sensíveis: {len(self.issues['dados_sensveis'])}")
        print(f"Problemas .env: {len(self.issues['env_leak'])}")
        print(f"Problemas Segurança: {len(self.issues['security_issues'])}")
        print(f"\nTotal de Problemas: {total_issues}")
        
        if total_issues == 0:
            print("\n✅ APK SEGURO PARA DEPLOY")
            print("   Nenhum dado pré-gravado ou credencial hardcoded detectado")
        else:
            print(f"\n⚠️  PROBLEMAS DETECTADOS - REVISÃO NECESSÁRIA")
        
        print("="*70 + "\n")
        
        return self.issues

def main():
    project_root = Path(__file__).parent
    analyzer = APKAnalyzer(project_root)
    
    print("\n🚀 INICIANDO ANÁLISE DO APK...\n")
    print("="*70)
    
    # Executar análises
    analyzer.check_env_file()
    analyzer.analyze_dart_files()
    analyzer.check_pubspec()
    analyzer.analyze_config_files()
    
    # Gerar relatório
    issues = analyzer.generate_report()
    
    # Salvar relatório em JSON
    report_file = project_root / 'relatorio_analise_apk.json'
    with open(report_file, 'w', encoding='utf-8') as f:
        json.dump({
            'timestamp': datetime.now().isoformat(),
            'project': str(project_root),
            'issues': issues
        }, f, indent=2, ensure_ascii=False)
    
    print(f"💾 Relatório salvo em: {report_file}\n")

if __name__ == '__main__':
    main()
