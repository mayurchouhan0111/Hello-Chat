import re

# Read the pubspec.yaml file
with open('pubspec.yaml', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
in_dependencies = False
in_dev_dependencies = False

for line in lines:
    if line.startswith('dependencies:'):
        in_dependencies = True
        in_dev_dependencies = False
        new_lines.append(line)
        continue
    elif line.startswith('dev_dependencies:'):
        in_dev_dependencies = True
        in_dependencies = False
        new_lines.append(line)
        continue
    elif line.startswith('flutter:'):
        in_dependencies = False
        in_dev_dependencies = False
        new_lines.append(line)
        continue

    if in_dependencies or in_dev_dependencies:
        # Match "package_name: ^version"
        # Only replace lines that have actual dependency lines (not sdk: flutter or comments)
        if re.search(r'^\s+[a-zA-Z0-9_]+:\s*\^[0-9\.]+(\+[0-9]+)?', line):
            # Replace the version with empty
            line = re.sub(r'(^\s+[a-zA-Z0-9_]+:)\s*\^[0-9\.]+(\+[0-9]+)?(.*?)', r'\1\3', line)
        elif re.search(r'^\s+[a-zA-Z0-9_]+:\s*any', line):
            line = re.sub(r'(^\s+[a-zA-Z0-9_]+:)\s*any(.*?)$', r'\1\2', line)
        
    new_lines.append(line)

with open('pubspec.yaml', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Versions stripped from pubspec.yaml")
