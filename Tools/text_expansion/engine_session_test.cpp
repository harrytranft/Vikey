// Integration regression: the shared TextExpansionSession must stay aligned with the real
// Engine/Driver edits, and an expansion must leave auto-switch/Backspace in a fresh context.
#include "Driver.h"
#include "TextExpansion.h"

#include <cstdio>
#include <string>
#include <vector>

int vLanguage = 1, vSwitchKeyStatus = 0, vCheckSpelling = 1, vUseModernOrthography = 1,
    vRestoreIfWrongSpelling = 1, vFixRecommendBrowser = 1, vUseSmartSwitchKey = 1,
    vOtherLanguage = 1, vAutoSwitchByTyping = 1;

using vikey::TextExpansionManager;
using vikey::TextExpansionSession;

static int failures = 0;
static void expect(bool ok, const char* name) {
    if (ok) return;
    std::printf("FAIL: %s\n", name);
    ++failures;
}

static Uint16 K(char c) {
    static const Uint16 L[26] = {
        KEY_A,KEY_B,KEY_C,KEY_D,KEY_E,KEY_F,KEY_G,KEY_H,KEY_I,KEY_J,KEY_K,KEY_L,KEY_M,
        KEY_N,KEY_O,KEY_P,KEY_Q,KEY_R,KEY_S,KEY_T,KEY_U,KEY_V,KEY_W,KEY_X,KEY_Y,KEY_Z
    };
    return L[c - 'a'];
}

static int scalarCount(const std::u16string& s) {
    int n = 0;
    for (std::size_t i = 0; i < s.size(); ++i) {
        char16_t c = s[i];
        if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.size() &&
            s[i + 1] >= 0xDC00 && s[i + 1] <= 0xDFFF) ++i;
        ++n;
    }
    return n;
}

static void eraseScalars(std::u16string& s, int n) {
    while (n-- > 0 && !s.empty()) {
        char16_t last = s.back();
        s.pop_back();
        if (last >= 0xDC00 && last <= 0xDFFF && !s.empty() &&
            s.back() >= 0xD800 && s.back() <= 0xDBFF) s.pop_back();
    }
}

static bool isBoundary(Uint16 key, bool shift, int language) {
    if (key == KEY_SPACE || key == KEY_RETURN || key == KEY_ENTER || key == KEY_TAB) return true;
    bool literalRightBracket = !(language == 1 && vTelexStyle == 0);
    if (!shift && (key == KEY_COMMA || key == KEY_DOT || key == KEY_SEMICOLON ||
                   (key == KEY_RIGHT_BRACKET && literalRightBracket))) return true;
    return shift && (key == KEY_SEMICOLON || key == KEY_SLASH || key == KEY_1 || key == KEY_0 ||
                     (key == KEY_RIGHT_BRACKET && literalRightBracket));
}

static char16_t boundaryChar(Uint16 key, bool shift) {
    if (key == KEY_RETURN || key == KEY_ENTER) return u'\n';
    if (key == KEY_TAB) return u'\t';
    return (char16_t)keyCodeToCharacter(key | (shift ? CAPS_MASK : 0));
}

class Harness {
public:
    Harness(int language = 1) {
        d.setLanguage(language);
        d.autoSwitch = true;
        d.pauseAfterManual = 0;
        m.setEntries({
            {u"dc", u"được"},
            {u"ss", u"Sun Santa"},
            {u"a", u"b"},
            {u"b", u"c"},
        });
    }

    void reset(int language) {
        d.setLanguage(language);
        d.resetContext();
        session.reset();
        screen.clear();
    }

    void resetCursorContext() {
        d.resetContext();
        session.reset();
    }

    void press(Uint16 key, bool shift = false) {
        const bool boundary = isBoundary(key, shift, d.language());
        if (boundary) {
            auto match = m.find(session.token(), false);
            if (match.matched) {
                eraseScalars(screen, match.deleteCount);
                screen += match.replacement;
                char16_t c = boundaryChar(key, shift);
                if (c) screen.push_back(c);
                session.reset();
                d.resetContext(); // what both desktop cores do after a successful expansion
                return;
            }
        }

        VKEdit e = d.press(key, shift);
        eraseScalars(screen, e.deleteCount);
        screen += e.text;

        if (boundary) {
            session.reset();
            return;
        }
        if (e.deleteCount > scalarCount(session.token())) {
            session.reset(); // same conservative guard as the desktop cores
            return;
        }
        session.applyEdit(e.deleteCount, e.text);
    }

    void typeLetters(const char* keys) {
        for (const char* p = keys; *p; ++p) {
            if (*p == ' ') press(KEY_SPACE);
            else if (*p == '<') press(KEY_DELETE);
            else press(K(*p));
        }
    }

    VikeyDriver d;
    TextExpansionManager m;
    TextExpansionSession session;
    std::u16string screen;
};

static void testEngineSessionSync() {
    Harness h(1);
    h.typeLetters("dd");
    expect(h.screen == u"đ" && h.session.token() == u"đ", "dd -> đ keeps session aligned");

    h.reset(1); h.typeLetters("aw");
    expect(h.screen == u"ă" && h.session.token() == u"ă", "aw -> ă keeps session aligned");

    h.reset(1); h.typeLetters("ow");
    expect(h.screen == u"ơ" && h.session.token() == u"ơ", "ow -> ơ keeps session aligned");

    h.reset(1); h.typeLetters("as");
    expect(h.screen == u"á" && h.session.token() == u"á", "tone edit keeps session aligned");

    h.press(KEY_DELETE);
    expect(h.screen.empty() && h.session.token().empty(), "Backspace after transformed letter keeps session aligned");
}

static void testExpansionAndFreshContext() {
    Harness h(1);
    h.typeLetters("dc ");
    expect(h.screen == u"được ", "Vietnamese-mode trigger expands at Space");
    expect(h.session.token().empty(), "session is empty after expansion");

    h.press(KEY_DELETE);
    expect(h.screen == u"được", "Backspace after expansion removes only boundary");
    expect(h.session.token().empty(), "Backspace does not reopen expanded trigger");

    h.reset(1);
    h.typeLetters("dc tomorrow ");
    expect(h.screen == u"được tomorrow ", "English word with doubled Telex key follows expansion unchanged");
    expect(h.d.language() == 0, "VI->EN auto switch still works after expansion");

    h.reset(0);
    h.typeLetters("ss vaayj ");
    expect(h.screen == u"Sun Santa vậy ", "normal Vietnamese word follows English-mode expansion");
    expect(h.d.language() == 1, "EN->VI auto switch still works after expansion");
}

static void testNoRecursiveExpansionAndContextReset() {
    Harness h(0);
    h.typeLetters("a ");
    expect(h.screen == u"b ", "replacement does not recursively expand");

    h.reset(0);
    h.typeLetters("ss");
    h.resetCursorContext();
    h.press(KEY_SPACE);
    expect(h.screen == u"ss ", "cursor/context reset prevents stale expansion");
}

static void testStandardTelexBracketBoundary() {
    Harness h(1);
    vTelexStyle = 0;
    h.typeLetters("dc");
    expect(!isBoundary(KEY_RIGHT_BRACKET, false, h.d.language()), "Standard Telex ] is not an expansion boundary");
    expect(!isBoundary(KEY_RIGHT_BRACKET, true, h.d.language()), "Standard Telex } key is reserved for uppercase ư");

    vTelexStyle = 1;
    expect(isBoundary(KEY_RIGHT_BRACKET, false, h.d.language()), "Simple Telex ] is a punctuation boundary");
    expect(isBoundary(KEY_RIGHT_BRACKET, true, h.d.language()), "Simple Telex } is a punctuation boundary");
    vTelexStyle = 0;
}

int main() {
    testEngineSessionSync();
    testExpansionAndFreshContext();
    testNoRecursiveExpansionAndContextReset();
    testStandardTelexBracketBoundary();

    std::printf("text expansion engine/session integration: %s\n", failures ? "FAIL" : "ok");
    return failures ? 1 : 0;
}
