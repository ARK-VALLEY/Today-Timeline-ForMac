// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// 实现思路参考 ddddxxx/TouchBarHelper（MPL-2.0）
// https://github.com/ddddxxx/TouchBarHelper
//
// DFRShim.m
// 与 LyricsX 的 TouchBarHelper 相同的实现方式：
// 动态加载 DFRFoundation 私有框架，并调用 NSTouchBar / NSTouchBarItem 的私有方法，
// 让内容以「系统级模态」常驻 Touch Bar（不受前台应用切换影响）。
// 若相关私有 API 不存在（如非 Touch Bar 机型 / 未来系统移除），所有调用静默降级，不影响主功能。

#import "DFRShim.h"
#import <dlfcn.h>

// ---- DFRFoundation 私有 C 函数（动态解析）----
static void (*pDFRElementSetControlStripPresenceForIdentifier)(NSString *, BOOL) = NULL;
static void (*pDFRSystemModalShowsCloseBoxWhenFrontMost)(BOOL) = NULL;

__attribute__((constructor))
static void DFRShimLoad(void) {
    const char *path = "/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation";
    void *handle = dlopen(path, RTLD_LAZY);
    if (handle == NULL) { return; }
    pDFRElementSetControlStripPresenceForIdentifier =
        dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier");
    pDFRSystemModalShowsCloseBoxWhenFrontMost =
        dlsym(handle, "DFRSystemModalShowsCloseBoxWhenFrontMost");
    dlclose(handle);
}

// ---- NSTouchBar 私有类方法声明（仅声明，运行时动态派发）----
@interface NSTouchBar (DFRPrivateDecl)
+ (void)presentSystemModalTouchBar:(NSTouchBar *)touchBar
         systemTrayItemIdentifier:(NSString *)identifier;
+ (void)presentSystemModalFunctionBar:(NSTouchBar *)touchBar
            systemTrayItemIdentifier:(NSString *)identifier;
+ (void)dismissSystemModalTouchBar:(NSTouchBar *)touchBar;
+ (void)dismissSystemModalFunctionBar:(NSTouchBar *)touchBar;
+ (void)minimizeSystemModalTouchBar:(NSTouchBar *)touchBar;
+ (void)minimizeSystemModalFunctionBar:(NSTouchBar *)touchBar;
@end

@interface NSTouchBarItem (DFRPrivateDecl)
+ (void)addSystemTrayItem:(NSTouchBarItem *)item;
+ (void)removeSystemTrayItem:(NSTouchBarItem *)item;
@end

@implementation NSTouchBarItem (DFRAccess)

- (void)addToSystemTray {
    if ([NSTouchBarItem respondsToSelector:@selector(addSystemTrayItem:)]) {
        [NSTouchBarItem addSystemTrayItem:self];
    }
}

- (void)removeFromSystemTray {
    if ([NSTouchBarItem respondsToSelector:@selector(removeSystemTrayItem:)]) {
        [NSTouchBarItem removeSystemTrayItem:self];
    }
}

- (void)setControlStripPresence:(BOOL)present {
    if (pDFRElementSetControlStripPresenceForIdentifier) {
        pDFRElementSetControlStripPresenceForIdentifier(self.identifier, present);
    }
}

@end

@implementation NSTouchBar (DFRAccess)

- (void)ttPresentAsSystemModalForItemIdentifier:(NSString *)identifier {
    if ([NSTouchBar respondsToSelector:@selector(presentSystemModalTouchBar:systemTrayItemIdentifier:)]) {
        [NSTouchBar presentSystemModalTouchBar:self systemTrayItemIdentifier:identifier];
    } else if ([NSTouchBar respondsToSelector:@selector(presentSystemModalFunctionBar:systemTrayItemIdentifier:)]) {
        [NSTouchBar presentSystemModalFunctionBar:self systemTrayItemIdentifier:identifier];
    }
}

- (void)ttMinimizeSystemModal {
    if ([NSTouchBar respondsToSelector:@selector(minimizeSystemModalTouchBar:)]) {
        [NSTouchBar minimizeSystemModalTouchBar:self];
    } else if ([NSTouchBar respondsToSelector:@selector(minimizeSystemModalFunctionBar:)]) {
        [NSTouchBar minimizeSystemModalFunctionBar:self];
    }
}

- (void)ttDismissSystemModal {
    if ([NSTouchBar respondsToSelector:@selector(dismissSystemModalTouchBar:)]) {
        [NSTouchBar dismissSystemModalTouchBar:self];
    } else if ([NSTouchBar respondsToSelector:@selector(dismissSystemModalFunctionBar:)]) {
        [NSTouchBar dismissSystemModalFunctionBar:self];
    }
}

+ (void)ttSetSystemModalShowsCloseBoxWhenFrontMost:(BOOL)show {
    if (pDFRSystemModalShowsCloseBoxWhenFrontMost) {
        pDFRSystemModalShowsCloseBoxWhenFrontMost(show);
    }
}

@end
