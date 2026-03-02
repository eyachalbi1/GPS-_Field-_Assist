# Read the file
with open('mobile/lib/screens/module_config_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find and replace the problematic section
# The issue is that we need to wrap the conditional properly

old_pattern = '''child: SafeArea(
          child: Column(
              if (_showResponseSection)
                Expanded('''

new_pattern = '''child: SafeArea(
          child: Column(
            children: [
              if (_showResponseSection)
                Expanded('''

content = content.replace(old_pattern, new_pattern)

# Also need to fix the closing - the Column children list needs proper closing
# We need to add the closing bracket for the children list

old_pattern2 = '''              Expanded(
                flex: 3,'''

new_pattern2 = '''              Expanded(
                flex: 3,'''

# Actually we need to add ] to close the children list properly
# Let me check for the pattern where we need to close

# The structure should be:
# Column(
#   children: [
#     if (condition) widget,
#     widget,
#   ],
# )

# So we need to find and fix the structure

# Find the pattern of the closing
old_closing = '''                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }'''

# After the main content, we need to add the closing bracket for the children list
# This is tricky - let me look at the actual structure

# Actually let's simplify - just fix the Column structure properly
# First let's find the broken pattern

# Fix: Column( if ( -> Column( children: [ if ( 
# And then make sure we have proper closing ]

# Let's try a different approach - find the SafeArea section and fix it
search = "child: SafeArea(\n          child: Column(\n              if (_showResponseSection)"
replace = "child: SafeArea(\n          child: Column(\n            children: [\n              if (_showResponseSection)"

if search in content:
    content = content.replace(search, replace)
    print("Fixed pattern 1")
else:
    print("Pattern 1 not found, trying alternative...")

# Now we need to add the closing bracket ] before the final );
# Find the pattern where the Column ends

# The pattern should be: ],\n          ),\n        ),\n      ),\n    );
# Let's find and add the closing

# Actually let's look at the specific area that needs fixing
# After Expanded(flex:3, ...) we need to close the children list

search2 = '''              Expanded(
                flex: 3,
                child: Column('''

replace2 = '''              ],
            ),
            Expanded(
              flex: 3,
              child: Column('''

if search2 in content:
    content = content.replace(search2, replace2)
    print("Fixed pattern 2")
else:
    print("Pattern 2 not found")

# Save
with open('mobile/lib/screens/module_config_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Done!")
