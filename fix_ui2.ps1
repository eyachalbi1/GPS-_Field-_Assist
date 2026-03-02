# Read the file
$content = Get-Content "mobile/lib/screens/module_config_screen.dart" -Raw

# Fix the syntax error - remove the extra );} at line ~393
$content = $content -replace "\);\s*\}\s*\n\s*void _clearTestResponses", "`n  void _clearTestResponses"

# Now add the conditional display for the response section
# Find the old top conversation section and replace it with conditional section

$oldTopSection = @'
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0C4D7A),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Rponses SMS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            if (_testCommandResponses.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.white70, size: 20),
                                onPressed: _clearConversation,
                                tooltip: 'Effacer la conversation',
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _testCommandResponses.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.sms_outlined,
                                      size: 60,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Aucun message',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Envoyez une commande pour demarrer',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _testCommandResponses.length,
                                itemBuilder: (context, index) {
                                  final msg = _testCommandResponses[index];
                                  return _buildSmsBubble(msg);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    if (_selectedTabIndex == 1) ...[
                      Expanded(
                        flex: 1,
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration:                                  color: Color const BoxDecoration(
(0xFF3498DB),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.message,
                                        color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Réponses SMS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_testCommandResponses.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.white70, size: 20),
                                        onPressed: _clearTestResponses,
                                        tooltip: 'Effacer',
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: _testCommandResponses.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.sms_outlined,
                                              size: 50,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'En attente de réponse',
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.all(12),
                                        itemCount: _testCommandResponses.length,
                                        itemBuilder: (context, index) {
                                          final msg =
                                              _testCommandResponses[index];
                                          return _buildSmsBubble(msg);
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      flex: _selectedTabIndex == 1 ? 1 : 2,
'@

$newTopSection = @'
        child: SafeArea(
          child: Column(
            children: [
              // Section Reponses SMS - affichee uniquement apres envoi SMS
              if (_showResponseSection) ...[
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFF3498DB),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.message,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Réponses SMS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              if (_testCommandResponses.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.white70, size: 20),
                                  onPressed: _clearTestResponses,
                                  tooltip: 'Effacer',
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _testCommandResponses.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.sms_outlined,
                                        size: 50,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'En attente de réponse',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _testCommandResponses.length,
                                  itemBuilder: (context, index) {
                                    final msg = _testCommandResponses[index];
                                    return _buildSmsBubble(msg);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              Expanded(
                flex: _showResponseSection ? 3 : 5,
'@

$content = $content -replace [regex]::Escape($oldTopSection), $newTopSection

# Save the file
$content | Set-Content "mobile/lib/screens/module_config_screen.dart" -Encoding UTF8

Write-Host "UI fixed successfully!"
