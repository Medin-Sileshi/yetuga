import os
import re
import glob

def replace_print_with_logger(file_path, log_tag):
    with open(file_path, 'r', encoding='utf-8') as file:
        content = file.read()

    # Replace print statements with Logger calls
    # Pattern: print('DEBUG: Some message');
    content = re.sub(
        r"print\('DEBUG: ([^']+)'\);",
        r"Logger.d('{}', '\1');".format(log_tag),
        content
    )

    # Pattern: print('DEBUG: Some message: $variable');
    content = re.sub(
        r"print\('DEBUG: ([^:]+): \$([^']+)'\);",
        r"Logger.d('{}', '\1: $\2');".format(log_tag),
        content
    )

    # Pattern: print('DEBUG: Error in method: $e');
    content = re.sub(
        r"print\('DEBUG: Error in ([^:]+): \$e'\);",
        r"Logger.e('{}', 'Error in \1', e);".format(log_tag),
        content
    )

    # Pattern: print('DEBUG: Error message: $e');
    content = re.sub(
        r"print\('DEBUG: ([^:]+Error[^:]*): \$e'\);",
        r"Logger.e('{}', '\1', e);".format(log_tag),
        content
    )

    # Pattern: print("Error message: $e");
    content = re.sub(
        r'print\("([^:]+Error[^:]*): \$e"\);',
        r"Logger.e('{}', '\1', e);".format(log_tag),
        content
    )

    # Pattern: print("Some message");
    content = re.sub(
        r'print\("([^"]+)"\);',
        r"Logger.d('{}', '\1');".format(log_tag),
        content
    )

    # Pattern: print("Some message: $variable");
    content = re.sub(
        r'print\("([^:]+): \$([^"]+)"\);',
        r"Logger.d('{}', '\1: $\2');".format(log_tag),
        content
    )

    with open(file_path, 'w', encoding='utf-8') as file:
        file.write(content)

    print(f"Replaced print statements in {file_path}")

def get_log_tag_from_path(file_path):
    # Extract class name from file path
    file_name = os.path.basename(file_path)
    class_name = os.path.splitext(file_name)[0]

    # Convert snake_case to CamelCase
    words = class_name.split('_')
    class_name = ''.join(word.capitalize() for word in words)

    return class_name

def add_logger_import(file_path):
    with open(file_path, 'r', encoding='utf-8') as file:
        content = file.read()

    # Check if Logger import already exists
    if "import 'package:yetuga/utils/logger.dart';" not in content:
        # Find the last import statement
        import_match = re.search(r'(import [^;]+;)\n', content)
        if import_match:
            last_import = import_match.group(0)
            # Add Logger import after the last import
            content = content.replace(
                last_import,
                last_import + "import 'package:yetuga/utils/logger.dart';\n"
            )

            with open(file_path, 'w', encoding='utf-8') as file:
                file.write(content)

            print(f"Added Logger import to {file_path}")

def process_file(file_path):
    log_tag = get_log_tag_from_path(file_path)
    add_logger_import(file_path)
    replace_print_with_logger(file_path, log_tag)

# Process specific files first
key_files = [
    'lib/screens/onboarding/onboarding_screen.dart',
    'lib/screens/onboarding/steps/display_name_step.dart',
    'lib/services/firebase_service.dart',
    'lib/main.dart',
    'lib/models/onboarding_data.dart',
    'lib/providers/auth_provider.dart',
    'lib/providers/onboarding_provider.dart',
    'lib/screens/auth/auth_screen.dart',
    'lib/screens/auth/email_signin_screen.dart',
    'lib/services/storage_service.dart'
]

for file_path in key_files:
    if os.path.exists(file_path):
        process_file(file_path)

# Process remaining Dart files
dart_files = glob.glob('lib/**/*.dart', recursive=True)
for file_path in dart_files:
    # Skip the logger.dart file and already processed files
    if file_path == 'lib/utils/logger.dart' or file_path in key_files:
        continue

    # Process the file
    process_file(file_path)
