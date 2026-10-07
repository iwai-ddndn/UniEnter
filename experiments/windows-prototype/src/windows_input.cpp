// Compile-check scaffold only: intentionally not called by windows_probe.cpp.
// Must not be wired to the hook before focus/IME validation and partial-send
// recovery exist. SendInput does not atomically target an HWND.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include "core.hpp"
namespace unienter {
struct SendResult { unsigned requested, inserted; DWORD error; };
SendResult sendPlanForFutureHarness(const Plan& plan) {
    INPUT inputs[6]{};
    if(plan.count>6) return {plan.count,0,ERROR_INVALID_PARAMETER};
    for(unsigned i=0;i<plan.count;++i) {
        auto& in=inputs[i]; const auto& s=plan.strokes[i]; in.type=INPUT_KEYBOARD;
        switch(s.key) {
            case VirtualKey::enter: in.ki.wVk=VK_RETURN; break;
            case VirtualKey::shift: in.ki.wVk=VK_LSHIFT; break;
            case VirtualKey::leftControl: in.ki.wVk=VK_LCONTROL; break;
            case VirtualKey::rightControl: in.ki.wVk=VK_RCONTROL; break;
        }
        in.ki.dwFlags=(s.up?KEYEVENTF_KEYUP:0)|(s.extended?KEYEVENTF_EXTENDEDKEY:0);
        in.ki.dwExtraInfo=0x554E4945; // additional origin marker, not a security boundary
    }
    if(!plan.count) return {0,0,ERROR_SUCCESS};
    SetLastError(ERROR_SUCCESS);
    UINT inserted=SendInput(plan.count,inputs,sizeof(INPUT));
    // Never retry Enter after zero/partial insertion: doing so may double-send.
    // Caller must disable rewriting and reconcile owned modifiers; not implemented.
    return {plan.count,inserted,inserted==plan.count?ERROR_SUCCESS:GetLastError()};
}
}
