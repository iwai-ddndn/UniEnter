#include "../src/core.hpp"
#include <cstdlib>
#include <iostream>
using namespace unienter;
unsigned checks=0;
void check(bool value,const char* why) { ++checks; if(!value) { std::cerr<<why<<'\n'; std::exit(1); } }
Context good() { return {true,true,true,true,true,true,Ime::idleVerified,1,1000}; }
int main() {
    for (auto url : {"https://chatgpt.com", "https://chatgpt.com/c/123", "https://chatgpt.com/?x=1"})
        check(chatgptUrl(url),"valid URL");
    for (auto url : {"http://chatgpt.com/", "https://chatgpt.com.evil/", "https://chatgpt.com@evil/", "https://evil/chatgpt.com", "chatgpt.com", "https://chatgpt.com:443/", "https://chatgpt.com\\@evil/"})
        check(!chatgptUrl(url),"reject ambiguous URL");
    for(unsigned m=0;m<32;++m) {
        Engine e; auto c=good();
        auto wanted=m==0?Action::newline:(m==leftCtrl||m==rightCtrl||m==(leftCtrl|rightCtrl))?Action::send:Action::pass;
        check(e.enter({true,false,false,m},c,1,1000)==wanted,"modifier decision");
        c.enabled=false; c.focus=2; c.ime=Ime::composing;
        auto paired=wanted==Action::pass?Action::pass:Action::swallow;
        check(e.enter({true,false,false,m},c,2,1100)==paired,"repeat across focus change");
        check(e.enter({false,false,false,m},c,2,1100)==paired,"keyup across focus change");
        check(e.enter({false,false,false,m},c,2,1100)==Action::pass,"no orphan swallow");
    }
    for(int failure=0;failure<11;++failure) {
        Engine e; auto c=good();
        switch(failure) {
            case 0:c.enabled=false;break; case 1:c.chrome=false;break;
            case 2:c.trustedOrigin=false;break; case 3:c.composer=false;break;
            case 4:c.normalIntegrity=false;break; case 5:c.suggestionClosed=false;break;
            case 6:c.ime=Ime::composing;break; case 7:c.ime=Ime::unknown;break;
            case 8:c.focus=2;break; case 9:c.sampledAt=899;break; case 10:c.sampledAt=1001;break;
        }
        check(e.enter({},c,1,1000)==Action::pass,"unsafe context passes");
        check(e.enter({},good(),1,1000)==Action::pass,"passed down stays passed on repeat");
        check(e.enter({false},good(),1,1000)==Action::pass,"passed down pairs");
    }
    Engine e;
    check(e.enter({true,false,true},good(),1,1000)==Action::pass,"injected down");
    check(e.enter({},good(),1,1000)==Action::newline,"injected does not latch physical key");
    check(e.enter({false,false,true},good(),1,1000)==Action::pass,"injected up");
    check(e.enter({true,true},good(),1,1000)==Action::newline,"numpad independent");
    check(e.enter({false},good(),1,1000)==Action::swallow,"main up");
    check(e.enter({false,true},good(),1,1000)==Action::swallow,"numpad up");
    check(!eligible(good(),0,1000),"unknown focus");
    check(eligible(good(),1,1100),"freshness inclusive");
    auto n=replacement(Action::newline,0,false);
    check(n.count==4 && n.strokes[0].key==VirtualKey::shift && !n.strokes[0].up && n.strokes[3].up,"newline plan");
    for(unsigned mods : {unsigned(leftCtrl),unsigned(rightCtrl),unsigned(leftCtrl|rightCtrl)}) {
        auto p=replacement(Action::send,mods,true);
        int l=0,r=0,enters=0;
        for(unsigned i=0;i<p.count;++i) { auto s=p.strokes[i];
            if(s.key==VirtualKey::leftControl) l+=s.up?-1:1;
            if(s.key==VirtualKey::rightControl) { r+=s.up?-1:1; check(s.extended,"right ctrl extended"); }
            if(s.key==VirtualKey::enter) { check(s.extended,"numpad flag"); if(!s.up) ++enters; }
        }
        check(l==0 && r==0 && enters==1,"control restoration and single send");
    }
    check(replacement(Action::send,leftCtrl|shift,false).count==0,"reject unsupported plan");
    check(replacement(Action::pass,0,false).count==0,"pass has no plan");
    std::cout<<checks<<" checks passed\n";
}
