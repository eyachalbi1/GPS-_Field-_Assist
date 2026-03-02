import re

# Read the file
with open('mobile/lib/screens/module_config_screen.dart', 'r', encoding='utf-8-sig') as f:
    content = f.read()

# Let's check for syntax issues in the conditional section
# First, let's see the structure around the conditional

# Find and fix the conditional section for the response display
# The issue is that we need proper Dart syntax with if statement

# Let's do a simpler approach - just ensure the conditional shows/hides properly

# Check if we have the if (_showResponseSection) [ pattern
# In Dart, we can use ternary operator or if statement in lists

# Let me check what's there now
print("Checking current state...")

# Fix any remaining syntax issues
# Check for the margin syntax error
if 'const EdgeInsets.fromL, 0' in content:
    content = content.replace('const EdgeInsets.fromL, 0', 'const EdgeInsets.fromLTRB(12, 0')
    print("Fixed margin syntax error")

if 'const EdgeInsets.fromL 0' in content:
    content = content.replace('const EdgeInsets.fromL 0', 'const EdgeInsets.fromLTRB(12, 0')
    print("Fixed margin syntax error 2")

# Save the file
with open('mobile/lib/screens/module_config_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("File saved!")

# Now let's try to verify using a Dart analyzer if available
# Otherwise, just print a summary
print("\nVerifying key patterns in the file...")

# Check for key elements
patterns = [
    ("if (_showResponseSection)", "Conditional section"),
    ("flex: _showResponseSection", "Dynamic flex value"),
    ("_clearTestResponses", "Clear function"),
    ("Conversation SMS", "Old label - should be gone"),
]

for pattern, desc in patterns:
    if pattern in content:
        print(f"  Found: {desc}")
    else:
        print(f"  Missing: {desc}")
