import re

# Read the file
with open('mobile/lib/screens/module_config_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the syntax error in margin
content = content.replace(
    'const EdgeInsets.fromL, 0, 12, TRB(128)',
    'const EdgeInsets.fromLTRB(12, 0, 12, 8)'
)

# Also check and fix any other syntax errors
# Fix the second occurrence if needed
content = content.replace(
    'const EdgeInsets.fromL 0, 12, TRB(128)',
    'const EdgeInsets.fromLTRB(12, 0, 12, 8)'
)

# Check for closing bracket issue in the conditional section
# The issue is that the Container needs to be properly closed
# Let's check if there's a missing closing bracket

# Find the section with the issue
pattern = r'if \(_showResponseSection\)\s*\[\s*Expanded\(\s*flex:\s*2,\s*child:\s*Container\(\s*margin:\s*const\s+EdgeInsets\.fromLTRB\(12,\s*12,\s*12,\s*8\),\s*decoration:'
if re.search(pattern, content):
    print("Found the conditional section, checking for bracket issues...")
    
# Fix: ensure proper closing of the Container widget before the Expanded
# The issue might be that we need to add proper closing

# Let's add the missing closing bracket for Container
content = content.replace(
    '''                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    decoration: BoxDecoration(''',
    '''                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        decoration: BoxDecoration('''
)

# Save the file
with open('mobile/lib/screens/module_config_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Additional fixes applied!")

# Now let's verify the file compiles
import subprocess
result = subprocess.run(
    ['python', '-c', 'import ast; ast.parse(open("mobile/lib/screens/module_config_screen.dart").read())'],
    capture_output=True,
    text=True,
    cwd='c:/Users/Asus/Desktop/gps-field-assist_ver_2_1_2'
)
if result.returncode == 0:
    print("File syntax is valid!")
else:
    print("Syntax error found:")
    print(result.stderr[:500])
