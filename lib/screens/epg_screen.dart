import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../data/epg_service.dart';
import '../models/epg_program.dart';
import '../models/content_item.dart';


/// Tela de Guia de Programação (EPG)
class EpgScreen extends StatefulWidget {
  final ContentItem? channel;
  
  const EpgScreen({super.key, this.channel});

  @override
  State<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends State<EpgScreen> {
  final ScrollController _channelScrollController = ScrollController();
  final ScrollController _programScrollController = ScrollController();
  
  List<EpgChannel> _channels = [];
  EpgChannel? _selectedChannel;
  int _selectedChannelIndex = 0;
  int _selectedProgramIndex = 0;
  bool _isLoading = true;
  String? _error;
  
  // Focus nodes
  final FocusNode _mainFocusNode = FocusNode();
  bool _isProgramListFocused = false;

  @override
  void initState() {
    super.initState();
    _loadEpg();
  }

  @override
  void dispose() {
    _channelScrollController.dispose();
    _programScrollController.dispose();
    _mainFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadEpg() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Tenta carregar do cache primeiro
      if (!EpgService.isLoaded) {
        final loaded = await EpgService.loadFromCache();
        if (!loaded && EpgService.epgUrl != null) {
          await EpgService.loadEpg(EpgService.epgUrl!);
        }
      }

      _channels = EpgService.getAllChannels();
      
      // Se foi passado um canal específico, seleciona ele
      if (widget.channel != null) {
        final epgChannel = EpgService.findChannelByName(widget.channel!.title);
        if (epgChannel != null) {
          final index = _channels.indexWhere((c) => c.id == epgChannel.id);
          if (index >= 0) {
            _selectedChannelIndex = index;
            _selectedChannel = epgChannel;
          }
        }
      }
      
      if (_selectedChannel == null && _channels.isNotEmpty) {
        _selectedChannel = _channels.first;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _selectChannel(int index) {
    if (index >= 0 && index < _channels.length) {
      setState(() {
        _selectedChannelIndex = index;
        _selectedChannel = _channels[index];
        _selectedProgramIndex = 0;
        _isProgramListFocused = false;
      });
      _scrollToChannel(index);
    }
  }

  void _scrollToChannel(int index) {
    if (_channelScrollController.hasClients) {
      final offset = index * 60.0;
      _channelScrollController.animateTo(
        offset.clamp(0, _channelScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToProgram(int index) {
    if (_programScrollController.hasClients) {
      final offset = index * 80.0;
      _programScrollController.animateTo(
        offset.clamp(0, _programScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final programs = _selectedChannel?.todayPrograms ?? [];

    if (!_isProgramListFocused) {
      // Navegação na lista de canais
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _selectChannel(_selectedChannelIndex + 1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _selectChannel(_selectedChannelIndex - 1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                 event.logicalKey == LogicalKeyboardKey.select ||
                 event.logicalKey == LogicalKeyboardKey.enter) {
        if (programs.isNotEmpty) {
          setState(() {
            _isProgramListFocused = true;
            _selectedProgramIndex = 0;
            // Tenta focar no programa ao vivo
            final liveIndex = programs.indexWhere((p) => p.isLive);
            if (liveIndex >= 0) {
              _selectedProgramIndex = liveIndex;
            }
          });
          _scrollToProgram(_selectedProgramIndex);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape ||
                 event.logicalKey == LogicalKeyboardKey.goBack) {
        Navigator.pop(context);
      }
    } else {
      // Navegação na lista de programas
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_selectedProgramIndex < programs.length - 1) {
          setState(() => _selectedProgramIndex++);
          _scrollToProgram(_selectedProgramIndex);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_selectedProgramIndex > 0) {
          setState(() => _selectedProgramIndex--);
          _scrollToProgram(_selectedProgramIndex);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                 event.logicalKey == LogicalKeyboardKey.escape ||
                 event.logicalKey == LogicalKeyboardKey.goBack) {
        setState(() => _isProgramListFocused = false);
      } else if (event.logicalKey == LogicalKeyboardKey.select ||
                 event.logicalKey == LogicalKeyboardKey.enter) {
        // Toggle favorito
        if (programs.isNotEmpty) {
          _toggleFavorite(programs[_selectedProgramIndex]);
        }
      }
    }
  }

  void _toggleFavorite(EpgProgram program) async {
    final programId = EpgService.getProgramId(program);
    if (EpgService.isFavorite(programId)) {
      await EpgService.removeFavorite(programId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removido dos favoritos: ${program.title}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      await EpgService.addFavorite(programId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Adicionado aos favoritos: ${program.title}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: KeyboardListener(
        focusNode: _mainFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Conteúdo
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorState()
                      : _channels.isEmpty
                          ? _buildEmptyState()
                          : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.calendar_today, color: AppColors.primary),
          const SizedBox(width: 12),
          const Text(
            'Guia de Programação',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Data atual
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatDate(DateTime.now()),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar EPG',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadEpg,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasEpgUrl = EpgService.epgUrl != null && EpgService.epgUrl!.isNotEmpty;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasEpgUrl ? Icons.cloud_download : Icons.tv_off, 
              color: Colors.white.withOpacity(0.3), 
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              hasEpgUrl 
                ? 'EPG não carregado'
                : 'EPG não configurado',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              hasEpgUrl
                ? 'Clique para baixar o guia de programação'
                : 'Configure a URL do EPG em Configurações > Guia de Programação',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (hasEpgUrl)
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  try {
                    await EpgService.loadEpg(EpgService.epgUrl!);
                    _channels = EpgService.getAllChannels();
                    if (_channels.isNotEmpty) {
                      _selectedChannel = _channels.first;
                    }
                    setState(() => _isLoading = false);
                  } catch (e) {
                    setState(() {
                      _isLoading = false;
                      _error = e.toString();
                    });
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Baixar EPG'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                icon: const Icon(Icons.settings),
                label: const Text('Ir para Configurações'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Row(
      children: [
        // Lista de canais
        SizedBox(
          width: 280,
          child: _buildChannelList(),
        ),
        
        // Separador
        Container(
          width: 1,
          color: Colors.white.withOpacity(0.1),
        ),
        
        // Lista de programas
        Expanded(
          child: _buildProgramList(),
        ),
      ],
    );
  }

  Widget _buildChannelList() {
    return Container(
      color: AppColors.backgroundDarker,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header da lista
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.live_tv, color: Colors.white.withOpacity(0.7), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Canais',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_channels.length}',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: Colors.white.withOpacity(0.1)),
          
          // Lista
          Expanded(
            child: ListView.builder(
              controller: _channelScrollController,
              itemCount: _channels.length,
              itemBuilder: (context, index) {
                final channel = _channels[index];
                final isSelected = index == _selectedChannelIndex;
                final currentProgram = channel.currentProgram;
                
                return GestureDetector(
                  onTap: () => _selectChannel(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected && !_isProgramListFocused
                          ? AppColors.primary.withOpacity(0.3)
                          : isSelected
                              ? Colors.white.withOpacity(0.1)
                              : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Ícone/Logo do canal
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: channel.icon != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    channel.icon!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.tv,
                                      color: Colors.white54,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.tv, color: Colors.white54),
                        ),
                        const SizedBox(width: 12),
                        
                        // Nome e programa atual
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                channel.displayName,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (currentProgram != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text(
                                        'AO VIVO',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        currentProgram.title,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramList() {
    final programs = _selectedChannel?.todayPrograms ?? [];
    
    if (programs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, color: Colors.white.withOpacity(0.3), size: 48),
            const SizedBox(height: 16),
            Text(
              'Sem programação disponível',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                _selectedChannel?.displayName ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${programs.length} programas',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ],
          ),
        ),
        
        Divider(height: 1, color: Colors.white.withOpacity(0.1)),
        
        // Lista de programas
        Expanded(
          child: ListView.builder(
            controller: _programScrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: programs.length,
            itemBuilder: (context, index) {
              final program = programs[index];
              final isSelected = index == _selectedProgramIndex && _isProgramListFocused;
              final isFavorite = EpgService.isFavorite(EpgService.getProgramId(program));
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _isProgramListFocused = true;
                    _selectedProgramIndex = index;
                  });
                },
                onLongPress: () => _toggleFavorite(program),
                child: _buildProgramItem(program, isSelected, isFavorite),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgramItem(EpgProgram program, bool isSelected, bool isFavorite) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withOpacity(0.3)
            : program.isLive
                ? Colors.green.withOpacity(0.1)
                : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : program.isLive
                  ? Colors.green.withOpacity(0.3)
                  : Colors.transparent,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Horário
            SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program.startTimeFormatted,
                    style: TextStyle(
                      color: program.isLive ? Colors.green : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    program.endTimeFormatted,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Indicador de status
            if (program.isLive)
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            else if (program.isUpcoming)
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            else
              const SizedBox(width: 4),
            
            const SizedBox(width: 12),
            
            // Conteúdo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Badge ao vivo
                      if (program.isLive) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AO VIVO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else if (program.isUpcoming) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            program.statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      
                      // Título
                      Expanded(
                        child: Text(
                          program.title,
                          style: TextStyle(
                            color: program.hasEnded ? Colors.white38 : Colors.white,
                            fontWeight: program.isLive ? FontWeight.bold : FontWeight.normal,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Descrição
                  if (program.description != null)
                    Text(
                      program.description!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                  // Barra de progresso (ao vivo)
                  if (program.isLive) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: program.progress,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation(Colors.green),
                              minHeight: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${program.remainingMinutes} min restantes',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Categoria e duração
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (program.category != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            program.category!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${program.durationMinutes} min',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Favorito
            IconButton(
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.amber : Colors.white38,
              ),
              onPressed: () => _toggleFavorite(program),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return '${weekdays[date.weekday % 7]}, ${date.day} ${months[date.month - 1]}';
  }
}
