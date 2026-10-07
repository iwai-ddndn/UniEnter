// Observation only. No physical key is swallowed or replaced by this executable.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <UIAutomation.h>
#include <wrl/client.h>
#include <atomic>
#include <chrono>
#include <cstdio>
#include <cwchar>
#include <cstring>
#include <thread>
#include "core.hpp"
using Microsoft::WRL::ComPtr;
static_assert(std::atomic<unsigned>::is_always_lock_free, "Hook counters must be lock-free");
static std::atomic<bool> stopped{false};
static std::atomic<unsigned> enters{0}, releases{0}, injected{0};
static DWORD loopThread=0;
LRESULT CALLBACK keyboard(int code, WPARAM kind, LPARAM data) {
    if(code==HC_ACTION) {
        const auto& k=*reinterpret_cast<KBDLLHOOKSTRUCT*>(data);
        if(k.vkCode==VK_RETURN) {
            if(k.flags&LLKHF_INJECTED) ++injected;
            else if(kind==WM_KEYDOWN || kind==WM_SYSKEYDOWN) ++enters;
            else if(kind==WM_KEYUP || kind==WM_SYSKEYUP) ++releases;
        }
    }
    // No UIA/COM, console I/O, SendInput, allocations, or blocking locks here.
    return CallNextHookEx(nullptr,code,kind,data);
}
BOOL WINAPI stop(DWORD signal) {
    if(signal==CTRL_C_EVENT || signal==CTRL_BREAK_EVENT) {
        stopped=true; PostThreadMessageW(loopThread,WM_QUIT,0,0); return TRUE;
    }
    return FALSE;
}
bool isChrome(DWORD pid) {
    HANDLE p=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,FALSE,pid);
    if(!p) return false;
    wchar_t path[32768]; DWORD n=32768;
    bool ok=QueryFullProcessImageNameW(p,0,path,&n)!=FALSE;
    CloseHandle(p);
    if(!ok) return false;
    const wchar_t* base=wcsrchr(path,L'\\');
    return base && _wcsicmp(base+1,L"chrome.exe")==0;
}
void observe() {
    if(FAILED(CoInitializeEx(nullptr,COINIT_MULTITHREADED))) return;
    {
        ComPtr<IUIAutomation> uia;
        auto hr=CoCreateInstance(CLSID_CUIAutomation,nullptr,CLSCTX_INPROC_SERVER,IID_PPV_ARGS(&uia));
        if(FAILED(hr)) std::printf("UIA unavailable (HRESULT %08lx)\n",static_cast<unsigned long>(hr));
        while(!stopped) {
            HWND before=GetForegroundWindow(); DWORD pid=0;
            DWORD tid=GetWindowThreadProcessId(before,&pid);
            bool chrome=isChrome(pid);
            int type=0; bool promptCandidate=false, documentAncestor=false, textEdit=false;
            bool activeComposition=false, compositionQueryOk=false;
            if(chrome && uia) {
                ComPtr<IUIAutomationElement> focused;
                if(SUCCEEDED(uia->GetFocusedElement(&focused)) && focused) {
                    int focusPid=0; focused->get_CurrentProcessId(&focusPid);
                    if(static_cast<DWORD>(focusPid)==pid) {
                        focused->get_CurrentControlType(&type);
                        BSTR id=nullptr;
                        if(SUCCEEDED(focused->get_CurrentAutomationId(&id)) && id)
                            promptCandidate=wcscmp(id,L"prompt-textarea")==0;
                        SysFreeString(id);
                        ComPtr<IUIAutomationTextEditPattern> edit;
                        textEdit=SUCCEEDED(focused->GetCurrentPatternAs(UIA_TextEditPatternId,IID_PPV_ARGS(&edit))) && edit;
                        if(textEdit) {
                            ComPtr<IUIAutomationTextRange> range;
                            compositionQueryOk=SUCCEEDED(edit->GetActiveComposition(&range));
                            activeComposition=range!=nullptr;
                        }
                        ComPtr<IUIAutomationTreeWalker> walker;
                        if(SUCCEEDED(uia->get_RawViewWalker(&walker)) && walker) {
                            auto node=focused;
                            for(int depth=0;depth<24 && node;++depth) {
                                CONTROLTYPEID ct=0; node->get_CurrentControlType(&ct);
                                if(ct==UIA_DocumentControlTypeId) { documentAncestor=true; break; }
                                ComPtr<IUIAutomationElement> parent;
                                if(FAILED(walker->GetParentElement(node.Get(),&parent))) break;
                                node=parent;
                            }
                        }
                    }
                }
            }
            bool stable=before==GetForegroundWindow();
            // Keyboard layout is diagnostic evidence, NOT composition state.
            auto language=LOWORD(reinterpret_cast<ULONG_PTR>(GetKeyboardLayout(tid)));
            std::printf("chrome=%d stableWindow=%d type=%d promptIdCandidate=%d document=%d textEdit=%d compositionQuery=%d activeRange=%d lang=%04x EnterDown=%u EnterUp=%u injected=%u remap=OFF\n",
                chrome,stable,type,promptCandidate,documentAncestor,textEdit,compositionQueryOk,activeComposition,
                static_cast<unsigned>(language),enters.exchange(0),releases.exchange(0),injected.exchange(0));
            std::fflush(stdout);
            std::this_thread::sleep_for(std::chrono::milliseconds(250));
        }
    }
    CoUninitialize();
}
int main(int argc, char** argv) {
    if(argc==2 && std::strcmp(argv[1],"--smoke")==0) {
        // CI: no hook, no UI inspection, no SendInput, no interactive desktop.
        auto init=CoInitializeEx(nullptr,COINIT_MULTITHREADED);
        if(FAILED(init)) return 2;
        HRESULT created;
        {
            ComPtr<IUIAutomation> uia;
            created=CoCreateInstance(CLSID_CUIAutomation,nullptr,CLSCTX_INPROC_SERVER,IID_PPV_ARGS(&uia));
        }
        CoUninitialize();
        std::printf("UIA COM creation smoke: %08lx\n",static_cast<unsigned long>(created));
        return SUCCEEDED(created)?0:3;
    }
    if(argc!=1) { std::fputs("Usage: unienter-probe.exe [--smoke]\n",stderr); return 4; }
    std::puts("UniEnter Windows diagnostic prototype. Remapping is OFF. Ctrl+C exits. No text or URL logging.");
    loopThread=GetCurrentThreadId();
    MSG msg{}; PeekMessageW(&msg,nullptr,WM_USER,WM_USER,PM_NOREMOVE);
    SetConsoleCtrlHandler(stop,TRUE);
    HHOOK hook=SetWindowsHookExW(WH_KEYBOARD_LL,keyboard,GetModuleHandleW(nullptr),0);
    if(!hook) { std::printf("Hook installation failed: %lu\n",GetLastError()); return 1; }
    std::thread worker(observe);
    int status;
    while((status=GetMessageW(&msg,nullptr,0,0))>0) { TranslateMessage(&msg); DispatchMessageW(&msg); }
    UnhookWindowsHookEx(hook); stopped=true;
    worker.join(); // A hung provider can delay shutdown; terminate process if needed.
    SetConsoleCtrlHandler(stop,FALSE);
    return status==-1?1:0;
}
