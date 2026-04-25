🎯 CORE IDEA
The system must support ONLY:
English (default, always available in app)
ONE alternative language (selected by Gym Owner)
No multi-language complexity beyond this.

👥 ROLES
Super Admin
Gym Owner
Branch Manager
Trainer
Member

🌍 LANGUAGE LOGIC
English
Always available
Bundled in the app
Used as fallback

Alternative Language
Selected by Gym Owner during registration
Only ONE alternative language allowed
Example: Georgian, Russian, etc.

Gym Owner Behavior
Receives alternative language after setup
Has language switch in Settings page: English / Alternative language

Member Behavior
Before joining a gym: Only English is available
No language switching
After gym approval: Receives language configuration from API, Downloads alternative language (if needed), Gets language switch in Settings page

⚙️ API BEHAVIOR
After gym approval, API should return ONLY metadata (NOT full language pack):
{
"alternativeLanguage": "ka",
"version": "v1"
}
Then the app must:

- Check if language is cached
- If not → download language pack via API

📦 LANGUAGE PACK
{
"lang": "ka",
"version": "v1",
"translations": {
"button.save": "შენახვა",
"menu.settings": "პარამეტრები"
}
}

🧠 TRANSLATION RULES
Only fixed UI strings are translated (buttons, labels, menus)
Dynamic/backend content must NOT be translated
Use key-based system: "button.save", "menu.settings"

🔁 FALLBACK SYSTEM
If translation missing: Alternative language → English → Key

⚡ PERFORMANCE RULES
Do NOT preload languages
Load alternative language only when needed
Cache language locally
Use versioning to update language packs
Language switching must NOT reload entire app

⚙️ SETTINGS PAGE (CRITICAL)
Language selector must exist inside Settings page
Visible for: Gym Owner + Members (only after approval)
UX should be simple: Toggle or dropdown

🤖 AI TRANSLATION SYSTEM + LOCO-STYLE EDITOR (WordPress Loco Translate)
Super Admin gets a full Loco-style translation management panel:

- Automatic string scanning from entire codebase (Flutter keys + backend strings)
- One-click “Scan Flutter codebase” button in admin
- Clean table view: English Key | English Text | Current Translation | Status
- Auto-detect missing translations (highlighted in red)
- Inline editing: click any translation → edit → Save
- "Generate with AI" button (AI receives all English keys → returns translated JSON, short & UI-friendly)
- Manual JSON upload / full replace
- Version control: every save bumps version (v1, v2...) + changelog
- Live preview mode (switch language instantly in admin panel)
- Export / Import JSON
- Search + filter by missing translations
- Offline-first fallback: if no internet, use last cached pack
- One-tap “Push to all gyms using this language” for Super Admin

Translations must be:
Short
UI-friendly
Not overly long

🎨 UI/UX REQUIREMENTS
UI must handle longer text (different languages)
Avoid fixed-width layouts
Support multiline text if needed
Prevent overflow or broken UI

🧱 YOUR TASK
Provide a complete plan including analysis, architecture, step-by-step integration, etc.

🔥 EXECUTION REQUIREMENTS
Include real code examples, sample API responses, sample JSON pack.
Be practical and implementation-ready.
