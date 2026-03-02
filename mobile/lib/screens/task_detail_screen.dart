import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/config.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _taskService = TaskService();
  final _descriptionController = TextEditingController();
  final List<XFile> _selectedFiles = [];
  final List<String> _uploadedUrls = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingMedia();
  }

  Future<void> _loadExistingMedia() async {
    try {
      final urls = await _taskService.getTaskMedia(widget.task.id);
      if (!mounted) return;
      setState(() => _uploadedUrls.addAll(urls));
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    setState(() => _selectedFiles.addAll(files));
  }

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun fichier sélectionné')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final urls =
          await _taskService.uploadFiles(widget.task.id, _selectedFiles);
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadedUrls.clear();
        _uploadedUrls.addAll(urls);
        _selectedFiles.clear();
        _descriptionController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fichiers téléchargés avec succès'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur upload: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _markAsCompleted() async {
    await _taskService.updateTaskStatus(widget.task.id, TaskStatus.completed);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Tâche marquée comme terminée'),
          backgroundColor: Colors.green),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5B7C99),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B7C99),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Détails de la tâche',
            style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF7A9AB8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Référence', widget.task.reference),
                    const SizedBox(height: 12),
                    _buildInfoRow('Nom de la tâche', widget.task.name),
                    const SizedBox(height: 12),
                    _buildInfoRow('Description', widget.task.description),
                    const SizedBox(height: 12),
                    _buildInfoRow('Nom du partenaire', widget.task.partnerName),
                    const SizedBox(height: 12),
                    _buildInfoRow('Horaire',
                        '${widget.task.startTime} - ${widget.task.endTime}'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_selectedFiles.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A9AB8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fichiers sélectionnés:',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(_selectedFiles.map((file) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.image,
                                    color: Colors.white70, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(file.name,
                                        style: const TextStyle(
                                            color: Colors.white70))),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red, size: 20),
                                  onPressed: () => setState(
                                      () => _selectedFiles.remove(file)),
                                ),
                              ],
                            ),
                          ))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_uploadedUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Médias:',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: GridView.builder(
                      scrollDirection: Axis.horizontal,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: _uploadedUrls.length,
                      itemBuilder: (context, i) {
                        final url = _uploadedUrls[i];
                        final full = url.startsWith('http')
                            ? url
                            : '${Config.effectiveUrl}${url}';
                        final uri = Uri.parse(url);
                        // extract filename for delete endpoint
                        final filename = uri.pathSegments.isNotEmpty
                            ? uri.pathSegments.last
                            : '';
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(full,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey,
                                      width: 120,
                                      height: 120)),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () async {
                                  try {
                                    await _taskService.deleteTaskMedia(
                                        widget.task.id, filename);
                                    if (!mounted) return;
                                    setState(() {
                                      _uploadedUrls.removeAt(i);
                                    });
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Erreur suppression: $e'),
                                          backgroundColor: Colors.red),
                                    );
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ajouter une description...',
                    hintStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF7A9AB8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                onPressed: _pickMedia,
                icon: const Icon(Icons.upload_file),
                label: const Text('Sélectionner des fichiers'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_selectedFiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadFiles,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload),
                  label:
                      Text(_isUploading ? 'Téléchargement...' : 'Télécharger'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (widget.task.status != TaskStatus.completed)
                ElevatedButton.icon(
                  onPressed: _markAsCompleted,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Marquer comme terminée'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF90EE90),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
