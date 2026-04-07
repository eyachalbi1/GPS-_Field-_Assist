import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/sms_history.dart';
import '../services/sms_history_service.dart';

class SmsHistoryScreen extends StatefulWidget {
  const SmsHistoryScreen({super.key});

  @override
  State<SmsHistoryScreen> createState() => _SmsHistoryScreenState();
}

class _SmsHistoryScreenState extends State<SmsHistoryScreen> {
  List<SmsHistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await SmsHistoryService.getHistory();
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  Color _getStatusColor(SmsHistoryStatus status) {
    switch (status) {
      case SmsHistoryStatus.sent:
      case SmsHistoryStatus.delivered:
        return const Color(0xFF2ECC71);
      case SmsHistoryStatus.pending:
        return const Color(0xFFF39C12);
      case SmsHistoryStatus.failed:
        return const Color(0xFFE74C3C);
      case SmsHistoryStatus.received:
        return const Color(0xFF3498DB);
    }
  }

  IconData _getStatusIcon(SmsHistoryStatus status) {
    switch (status) {
      case SmsHistoryStatus.sent:
      case SmsHistoryStatus.delivered:
        return Icons.check_circle;
      case SmsHistoryStatus.pending:
        return Icons.access_time;
      case SmsHistoryStatus.failed:
        return Icons.error;
      case SmsHistoryStatus.received:
        return Icons.reply;
    }
  }

  void _showDetailDialog(SmsHistoryItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.message, color: Color(0xFF0C4D7A), size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Détails SMS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0C4D7A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildDetailRow(
                Icons.phone,
                'Téléphone',
                item.phone,
                const Color(0xFF3498DB),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.send,
                'Commande',
                item.command,
                const Color(0xFF9B59B6),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                _getStatusIcon(item.status),
                'Statut',
                item.status.label,
                _getStatusColor(item.status),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.access_time,
                'Date/Heure',
                '${item.timestamp.day.toString().padLeft(2, '0')}/${item.timestamp.month.toString().padLeft(2, '0')}/${item.timestamp.year} ${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                const Color(0xFF95A5A6),
              ),
              if (item.response != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2ECC71)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.reply, color: Color(0xFF2ECC71), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Réponse',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2ECC71),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.response!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique SMS', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.c1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Effacer l\'historique'),
                    content: const Text(
                        'Voulez-vous vraiment effacer tout l\'historique ?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC143C)),
                        child: const Text('Effacer'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await SmsHistoryService.clearHistory();
                  _loadHistory();
                }
              },
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C4D7A), Color(0xFF1E5A7A)],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : _history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 80, color: AppTheme.c2.withOpacity(0.7)),
                        SizedBox(height: 16),
                        Text(
                          'Aucun SMS envoyé',
                          style: TextStyle(color: AppTheme.c2, fontSize: 18),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: AppTheme.cardBlue(radius: 12),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF0C4D7A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.terminal,
                                  color: Color(0xFF0C4D7A),
                                ),
                              ),
                              title: Text(
                                item.moduleName ?? 'Commande Test',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${item.timestamp.day.toString().padLeft(2, '0')}/${item.timestamp.month.toString().padLeft(2, '0')}/${item.timestamp.year} ${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.phone,
                                          size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Téléphone',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        item.phone,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.send,
                                          size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Commande',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.command,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(item.status)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getStatusIcon(item.status),
                                          size: 16,
                                          color: _getStatusColor(item.status),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Réponse',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          item.response ?? item.status.label,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _getStatusColor(item.status),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showDetailDialog(item),
                                      icon: const Icon(Icons.visibility,
                                          size: 18),
                                      label: const Text('Voir'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.skyBottom,
                                        foregroundColor: AppTheme.c1,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}





