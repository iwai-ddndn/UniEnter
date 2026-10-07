#pragma once
#include <array>
#include <cstdint>
#include <string_view>
namespace unienter {
enum class Ime { unknown, composing, idleVerified };
enum class Action { pass, newline, send, swallow };
enum Modifier : unsigned { shift=1, leftCtrl=2, rightCtrl=4, alt=8, win=16 };
struct Context {
    bool enabled=false, chrome=false, trustedOrigin=false, composer=false;
    bool normalIntegrity=false, suggestionClosed=false;
    Ime ime=Ime::unknown;
    std::uint64_t focus=0, sampledAt=0;
};
// Strict allowlist. Input must be a URL established from trusted browser chrome,
// never document text, window title, accessibility Name, or the omnibox being edited.
inline bool chatgptUrl(std::string_view url) {
    constexpr std::string_view prefix="https://chatgpt.com";
    if (url.substr(0,prefix.size())!=prefix) return false;
    return url.size()==prefix.size() || url[prefix.size()]=='/' ||
           url[prefix.size()]=='?' || url[prefix.size()]=='#';
}
inline bool eligible(const Context& c, std::uint64_t focus, std::uint64_t now) {
    return c.enabled && c.chrome && c.trustedOrigin && c.composer &&
        c.normalIntegrity && c.suggestionClosed && c.ime==Ime::idleVerified &&
        focus!=0 && c.focus==focus && now>=c.sampledAt && now-c.sampledAt<=100;
}
struct Key { bool down=true, extended=false, injected=false; unsigned modifiers=0; };
// Enter only. Physical key pairing survives focus/IME/enable changes.
// One complete synthetic tap per physical press; repeats cannot send twice.
class Engine {
    struct Press { bool held=false, consumed=false; };
    std::array<Press,2> presses_{};
public:
    Action enter(Key key, const Context& c, std::uint64_t focus, std::uint64_t now) {
        if (key.injected) return Action::pass;
        auto& p=presses_[key.extended?1:0];
        if (!key.down) {
            bool consumed=p.consumed; p={};
            return consumed?Action::swallow:Action::pass;
        }
        if (p.held) return p.consumed?Action::swallow:Action::pass;
        p.held=true;
        if (!eligible(c,focus,now)) return Action::pass;
        Action a=Action::pass;
        if (key.modifiers==0) a=Action::newline;
        else if ((key.modifiers & (leftCtrl|rightCtrl)) &&
                 !(key.modifiers & ~(leftCtrl|rightCtrl))) a=Action::send;
        p.consumed=a!=Action::pass;
        return a;
    }
};
enum class VirtualKey { enter, shift, leftControl, rightControl };
struct Stroke { VirtualKey key=VirtualKey::enter; bool up=false, extended=false; };
struct Plan { std::array<Stroke,6> strokes{}; unsigned count=0;
    void add(VirtualKey k,bool up=false,bool ext=false) { strokes[count++]={k,up,ext}; }
};
inline Plan replacement(Action action, unsigned modifiers, bool extended) {
    Plan p;
    if (action==Action::newline && modifiers==0) {
        p.add(VirtualKey::shift); p.add(VirtualKey::enter,false,extended);
        p.add(VirtualKey::enter,true,extended); p.add(VirtualKey::shift,true);
    } else if (action==Action::send && (modifiers & (leftCtrl|rightCtrl)) &&
               !(modifiers & ~(leftCtrl|rightCtrl))) {
        if (modifiers&leftCtrl) p.add(VirtualKey::leftControl,true);
        if (modifiers&rightCtrl) p.add(VirtualKey::rightControl,true,true);
        p.add(VirtualKey::enter,false,extended); p.add(VirtualKey::enter,true,extended);
        if (modifiers&leftCtrl) p.add(VirtualKey::leftControl);
        if (modifiers&rightCtrl) p.add(VirtualKey::rightControl,false,true);
    }
    return p;
}
}
