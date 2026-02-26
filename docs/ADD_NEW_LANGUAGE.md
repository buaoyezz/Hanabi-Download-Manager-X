# Adding a New Language Translation

[中文版本](ADD_NEW_LANGUAGE_CN.md)

This guide explains how to add a new language translation to Hanabi Download Manager X.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Step-by-Step Guide](#step-by-step-guide)
- [File Structure](#file-structure)
- [Translation Keys](#translation-keys)
- [Testing Your Translation](#testing-your-translation)
- [Troubleshooting](#troubleshooting)

---

## Overview

Hanabi Download Manager X uses ARB (Application Resource Bundle) files for internationalization. Each language is defined in a separate `.arb` file located in the `lang/` directory.

The application supports:
- Built-in languages: English (en), Chinese (zh)
- Custom language packs: Any language loaded from `lang/` directory

---

## Prerequisites

Before you begin, ensure you have:
- A text editor (VS Code, Sublime Text, Notepad++, etc.)
- Basic understanding of JSON format
- The Chinese language pack (`lib/l10n/app_zh.arb`) as a reference

---

## Step-by-Step Guide

### Step 1: Create the Language Pack File

1. Navigate to the `lang/` directory in the project root
2. Create a new file named `app_<locale>.arb`
   - For Japanese: `app_ja.arb`
   - For Korean: `app_ko.arb`
   - For French: `app_fr.arb`
   - For German: `app_de.arb`

### Step 2: Set Up the File Structure

Open your new file and add the following required fields:

```json
{
  "@@locale": "ja",
  "@@languageName": "Japanese",
  "appTitle": "Hanabi Download Manager X"
}
```

**Required Fields:**
- `@@locale`: The locale code (e.g., `ja`, `ko`, `fr`, `de`)
- `@@languageName`: The display name in the language selector
- All other translation keys from `lib/l10n/app_zh.arb`

### Step 3: Copy Translation Keys

1. Open `lib/l10n/app_zh.arb` as a reference
2. Copy all translation keys (except those starting with `@@`)
3. Paste them into your new language file
4. Translate each value to your target language

**Example:**

```json
{
  "@@locale": "ja",
  "@@languageName": "Japanese",
  "appTitle": "Hanabi Download Manager X",
  "aboutPageTitle": "About",
  "settingsTitle": "Settings",
  "downloadEmptyTitle": "No downloads",
  "downloadEmptySubtitle": "Click the New button to add a download task"
}
```

### Step 4: Handle Placeholders

Some translation strings contain placeholders in the format `{variable}`. Keep these placeholders unchanged:

```json
{
  "aboutVersionLabel": "v{version}",
  "appearanceLanguageSwitchedTo": "Switched to {language}",
  "updateAvailableMessage": "New version {newVersion} is available"
}
```

### Step 5: Save and Validate

1. Save your file with UTF-8 encoding
2. Ensure the JSON syntax is valid (use a JSON validator if needed)
3. Check that all required keys are present

---

## File Structure

### Directory Layout

```
project-root/
├── lang/                          # Custom language packs
│   ├── app_ja.arb                # Japanese
│   ├── app_ko.arb                # Korean
│   └── app_fr.arb                # French
└── lib/
    └── l10n/                      # Built-in languages
        ├── app_en.arb            # English (reference)
        └── app_zh.arb            # Chinese (reference)
```

### ARB File Format

```json
{
  "@@locale": "locale_code",
  "@@languageName": "Display Name",
  "key1": "Translation 1",
  "key2": "Translation 2",
  "keyWithPlaceholder": "Text with {variable}"
}
```

---

## Translation Keys

### Key Categories

The application has approximately 1,235 translation keys organized into categories:

1. **General UI**
   - `appTitle`, `aboutPageTitle`, `settingsTitle`
   
2. **Navigation**
   - `homeNavDownloading`, `homeNavCompleted`, `homeNavSettings`
   
3. **Download Management**
   - `downloadEmptyTitle`, `addDownloadTitle`, `fileName`, `speed`
   
4. **Settings**
   - `settingsAutoStartTitle`, `settingsDownloadPathTitle`
   
5. **Appearance**
   - `appearanceLanguageTitle`, `appearanceWindowSizeSection`
   
6. **Notifications**
   - `settingsAutoStartEnabledTitle`, `updateAvailableTitle`

### Finding All Keys

To see all available translation keys:
1. Open `lib/l10n/app_zh.arb`
2. All keys (except those starting with `@@`) need to be translated

---

## Testing Your Translation

### Step 1: Load the Language Pack

1. Launch Hanabi Download Manager X
2. Navigate to: **Settings** → **Appearance** → **Language**
3. Click the **Refresh language packs** button
4. Your new language should appear in the dropdown

### Step 2: Switch Language

1. Select your new language from the dropdown
2. The application will reload with your translations
3. Verify that all text displays correctly

### Step 3: Check for Issues

Look for:
- Missing translations (showing English fallback)
- Incorrect placeholders
- Text overflow or layout issues
- Special characters not displaying correctly

---

## Troubleshooting

### Language Not Appearing

**Problem:** Your language doesn't show up in the language selector.

**Solutions:**
1. Verify the file is in the `lang/` directory
2. Check that the filename follows the pattern `app_<locale>.arb`
3. Ensure `@@locale` and `@@languageName` are set correctly
4. Click **Refresh language packs** again

### JSON Syntax Error

**Problem:** Application shows "Failed to load pack" error.

**Solutions:**
1. Validate your JSON syntax using an online validator
2. Check for:
   - Missing commas between entries
   - Unescaped quotes in strings (use `\"` for quotes)
   - Missing closing braces `}`
3. Ensure UTF-8 encoding without BOM

### Missing Translations

**Problem:** Some text shows in English instead of your language.

**Solutions:**
1. Compare your file with `lib/l10n/app_zh.arb`
2. Ensure all keys are present
3. Check that no values are empty strings

### Special Characters Not Displaying

**Problem:** Characters like Chinese, Japanese, or Arabic don't display correctly.

**Solutions:**
1. Save the file with UTF-8 encoding
2. Avoid using UTF-8 with BOM
3. Test with a simple character first

---

## Example: Creating a Japanese Translation

### 1. Create the File

Create `lang/app_ja.arb`:

```json
{
  "@@locale": "ja",
  "@@languageName": "Japanese",
  "appTitle": "Hanabi Download Manager X",
  "aboutPageTitle": "について",
  "settingsTitle": "設定",
  "homeNavDownloading": "ダウンロード中",
  "homeNavCompleted": "完了",
  "homeNavSettings": "設定",
  "downloadEmptyTitle": "ダウンロードがありません",
  "downloadEmptySubtitle": "新規ボタンをクリックしてダウンロードタスクを追加",
  "fileName": "ファイル名",
  "speed": "速度",
  "status": "状態"
}
```

### 2. Load and Test

1. Open the application
2. Go to Settings → Appearance → Language
3. Click **Refresh language packs**
4. Select **Japanese** from the dropdown
5. Verify the translations

---

## Best Practices

### Translation Guidelines

1. **Consistency**: Use consistent terminology throughout
2. **Context**: Consider the UI context when translating
3. **Length**: Keep translations similar in length to avoid layout issues
4. **Formality**: Match the tone of the original text
5. **Placeholders**: Never translate placeholder names like `{version}`

### Quality Checklist

- [ ] All keys from `app_zh.arb` are present
- [ ] `@@locale` and `@@languageName` are set correctly
- [ ] JSON syntax is valid
- [ ] File is saved with UTF-8 encoding
- [ ] Placeholders are preserved unchanged
- [ ] Translations are contextually appropriate
- [ ] No empty string values
- [ ] Tested in the application

---

## Contributing Your Translation

If you'd like to contribute your translation to the project:

1. Test thoroughly in the application
2. Create a pull request with your `.arb` file
3. Include a brief description of the language
4. Mention any special considerations

See [CONTRIBUTING.md](../CONTRIBUTING.md) for more details.

---

## Additional Resources

- [Flutter Internationalization](https://docs.flutter.dev/development/accessibility-and-localization/internationalization)
- [ARB File Format](https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification)
- [JSON Validator](https://jsonlint.com/)
- [Locale Codes](https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry)

---

## Support

If you encounter issues or have questions:
- Open an issue on GitHub
- Check existing translations for reference
- Refer to `lib/l10n/app_zh.arb` as the complete key list

---

**Last Updated:** 2024-01-20
