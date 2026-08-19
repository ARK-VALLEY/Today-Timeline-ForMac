// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// 实现思路参考 ddddxxx/TouchBarHelper（MPL-2.0）
// https://github.com/ddddxxx/TouchBarHelper
//
// 桥接头文件：把 ObjC 侧封装的 Touch Bar 私有 API 暴露给 Swift
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTouchBarItem (DFRAccess)

/// 把该 item 加入系统托盘（Control Strip）
- (void)addToSystemTray;

/// 从系统托盘移除
- (void)removeFromSystemTray;

/// 控制该 item 在 Control Strip 中的常驻显示
- (void)setControlStripPresence:(BOOL)present;

@end

@interface NSTouchBar (DFRAccess)

/// 以系统级模态呈现（内容常驻，不受前台应用切换影响），itemIdentifier 会作为托盘按钮
- (void)ttPresentAsSystemModalForItemIdentifier:(NSString *)identifier;

/// 收起系统级模态（托盘按钮仍在）
- (void)ttMinimizeSystemModal;

/// 完全关闭系统级模态
- (void)ttDismissSystemModal;

/// 隐藏模态栏上的关闭按钮
+ (void)ttSetSystemModalShowsCloseBoxWhenFrontMost:(BOOL)show;

@end

NS_ASSUME_NONNULL_END
