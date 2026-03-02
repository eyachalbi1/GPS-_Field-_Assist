import re

# Read the file
with open('mobile/lib/screens/module_config_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace "flex: 2," with conditional expanded section
# This is the first Expanded(flex: 2) that shows the conversation at the top
pattern = r'(Expanded\(\s*flex:\s*2,\s*child:\s*Container\(\s*margin:\s*const\s+EdgeInsets\.all\(12\),)'

replacement = r'''if (_showResponseSection) [
                  Expanded(
                    flex: 2,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),'''

content = re.sub(pattern, replacement, content)

# Replace the second Expanded(flex: 3) to use conditional flex
# When _showResponseSection is false, it should take more space
content = content.replace(
    'Expanded(\n                  flex: 3,\n                  child: Column(\n                    children: [\n                      if (_selectedTabIndex == 1)',
    'Expanded(\n                  flex: _showResponseSection ? 3 : 5,\n                  child: Column(\n                    children: [\n                      if (_selectedTabIndex == 1)'
)

# Also fix the flex value in the inner Expanded
content = content.replace(
    'Expanded(\n                        flex: 1,\n                        child: Container(\n                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),',
    'Expanded(\n                        flex: _showResponseSection ? 1 : 0,\n                        child: Container(\n                          margin: const EdgeInsets.fromL, 0, 12, TRB(128),'
)

# Save the file
with open('mobile/lib/screens/module_config_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("UI fixed successfully!")
