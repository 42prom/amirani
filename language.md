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
Has language switch in Settings page:
English / Alternative language
Member Behavior
Before joining a gym:
Only English is available
No language switching
After gym approval:
Receives language configuration from API
Downloads alternative language (if needed)
Gets language switch in Settings page
⚙️ API BEHAVIOR

After gym approval, API should return ONLY metadata (NOT full language pack):

Example:
{
"alternativeLanguage": "ka",
"version": "v1"
}

Then the app must:

Check if language is cached
If not → download language pack via API
📦 LANGUAGE PACK

Example:
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
Use key-based system:
"button.save"
"menu.settings"
🔁 FALLBACK SYSTEM

If translation missing:

Alternative language
English
Key
⚡ PERFORMANCE RULES
Do NOT preload languages
Load alternative language only when needed
Cache language locally
Use versioning to update language packs
Language switching must NOT reload entire app
⚙️ SETTINGS PAGE (CRITICAL)
Language selector must exist inside Settings page
Visible for:
Gym Owner
Members (only after approval)
UX should be simple:
Toggle or dropdown (your choice)
🤖 AI TRANSLATION SYSTEM

Design a system where:

Super Admin can generate language packs using AI
AI receives English keys and returns translated JSON
Translations must be:
Short
UI-friendly
Not overly long

Also include:

Ability to edit translations manually
Version control for updates
🎨 UI/UX REQUIREMENTS
UI must handle longer text (different languages)
Avoid fixed-width layouts
Support multiline text if needed
Prevent overflow or broken UI
🧱 YOUR TASK

Provide a complete plan including:

Analysis of current system limitations
Architecture design (backend + Flutter)
Step-by-step integration plan (without breaking existing system)
Language loading & switching flow
Settings page UX design
API structure
Caching & versioning strategy
AI translation workflow
Edge cases handling (offline, missing translations, etc.)
🔥 EXECUTION REQUIREMENTS
Include real Flutter code examples (at least 2–3)
Include sample API responses
Include sample JSON language pack
Be practical and implementation-ready
Avoid vague explanations

Your goal is to design the best possible system based on this idea, improving it if necessary while keeping it simple and scalable.
