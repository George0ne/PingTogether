#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudio.h>

// Clockwise, starting at the left: matches the reference wheel.
static NSArray<NSString *> *Labels(void) { return @[@"敌人不见了", @"敌方视野", @"危险", @"推进", @"正在路上", @"全力进攻", @"协助我", @"需要视野"]; }
static NSArray<NSString *> *Textures(void) { return @[@"enemy_missing", @"enemy_vision", @"pingwheel_retreatrender", @"push", @"omw", @"all_in", @"assist_me", @"need_vision"]; }
static NSArray<NSString *> *Sounds(void) { return @[@"MIA", @"AreaIsWarded", @"SRP_12", @"SRP_9", @"OnMyWay", @"SRP_4", @"ComeHere", @"SRP_7"]; }
static NSColor *Gold(void) { return [NSColor colorWithSRGBRed:0.96 green:0.79 blue:0.39 alpha:1]; }
static NSColor *Mint(void) { return [NSColor colorWithSRGBRed:0.35 green:0.89 blue:0.83 alpha:1]; }
static NSString *Asset(NSString *group, NSString *name, NSString *ext) {
    NSString *relative=[NSString stringWithFormat:@"assets/%@/%@.%@",group,name,ext];
    return [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:relative];
}
static NSImage *Texture(NSString *name) {
    static NSMutableDictionary *cache; if (!cache) cache=[NSMutableDictionary new];
    NSImage *image=cache[name];
    if (!image) { image=[[NSImage alloc] initWithContentsOfFile:Asset(@"textures",name,@"png")]; if(image) cache[name]=image; }
    return image;
}
static NSData *PingSound(NSInteger kind);
static NSInteger Selection(NSPoint p, NSPoint center) {
    CGFloat dx=p.x-center.x,dy=p.y-center.y;
    if (hypot(dx,dy)<82) return -1;
    double clockwise=fmod(180-atan2(dy,dx)*180/M_PI+360,360);
    return ((NSInteger)floor((clockwise+22.5)/45))%8;
}
typedef struct { BOOL down; BOOL wheel; } HoldState;
static BOOL BeginHold(HoldState *s) {
    if (s->down) return NO;
    s->down=YES;s->wheel=YES;return YES;
}
static BOOL EndHold(HoldState *s) {
    BOOL send=s->wheel;s->down=NO;s->wheel=NO;return send;
}
static void CancelHold(HoldState *s) { s->wheel=NO; }
static NSString *OutputStatus(void) {
    AudioDeviceID device=0;UInt32 size=sizeof(device);
    AudioObjectPropertyAddress address={kAudioHardwarePropertyDefaultOutputDevice,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
    if(AudioObjectGetPropertyData(kAudioObjectSystemObject,&address,0,NULL,&size,&device)!=noErr || device==kAudioObjectUnknown) return @"未检测到系统输出设备。";
    CFStringRef name=NULL;size=sizeof(name);address.mSelector=kAudioObjectPropertyName;
    AudioObjectGetPropertyData(device,&address,0,NULL,&size,&name);
    NSString *label=name?CFBridgingRelease(name):@"默认输出设备";
    UInt32 mute=0;size=sizeof(mute);address=(AudioObjectPropertyAddress){kAudioDevicePropertyMute,kAudioDevicePropertyScopeOutput,kAudioObjectPropertyElementMain};
    OSStatus result=AudioObjectGetPropertyData(device,&address,0,NULL,&size,&mute);
    if(result==noErr && mute) return [NSString stringWithFormat:@"%@：系统已静音。请先解除 macOS 系统静音，再测试。",label];
    return [NSString stringWithFormat:@"当前输出：%@。%@",label,result==noErr?@"系统未静音。":@"无法读取此设备的静音状态。"];
}
static NSBezierPath *Circle(NSPoint c, CGFloat r) { return [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(c.x-r,c.y-r,2*r,2*r)]; }
static void StrokeCircle(NSPoint c, CGFloat r, NSColor *color, CGFloat width) {
    NSBezierPath *p=Circle(c,r); [color setStroke];p.lineWidth=width;[p stroke];
}
static void Art(NSString *name, NSRect rect, CGFloat alpha, BOOL gold) {
    NSImage *source=Texture(name); if (!source) return;
    if (gold) {
        // Runtime colour treatment keeps the texture's shading and alpha.
        static NSMutableDictionary *tints; if (!tints) tints=[NSMutableDictionary new];
        NSImage *tinted=tints[name];
        if (!tinted) {
            tinted=[source copy]; [tinted lockFocus];
            [[NSColor colorWithSRGBRed:0.89 green:0.76 blue:0.42 alpha:0.73] setFill];
            NSRectFillUsingOperation(NSMakeRect(0,0,tinted.size.width,tinted.size.height),NSCompositingOperationSourceAtop);
            [tinted unlockFocus];tints[name]=tinted;
        } source=tinted;
    }
    [source drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:alpha respectFlipped:NO hints:@{NSImageHintInterpolation:@(NSImageInterpolationHigh)}];
}
static void Text(NSString *s, NSPoint center, CGFloat size, NSColor *color, NSFontWeight weight) {
    NSDictionary *a = @{NSFontAttributeName:[NSFont systemFontOfSize:size weight:weight], NSForegroundColorAttributeName:color};
    NSSize z = [s sizeWithAttributes:a];
    [s drawAtPoint:NSMakePoint(center.x-z.width/2, center.y-z.height/2) withAttributes:a];
}
static NSData *Tone(NSInteger kind) {
    const uint32_t rate=44100, count=(uint32_t)(rate*0.42), bytes=count*2;
    NSMutableData *d=[NSMutableData dataWithLength:44+bytes];
    uint8_t *b=d.mutableBytes;
    memcpy(b,"RIFF",4); uint32_t n=CFSwapInt32HostToLittle(36+bytes); memcpy(b+4,&n,4);
    memcpy(b+8,"WAVEfmt ",8); n=CFSwapInt32HostToLittle(16); memcpy(b+16,&n,4);
    uint16_t v=CFSwapInt16HostToLittle(1); memcpy(b+20,&v,2); memcpy(b+22,&v,2);
    n=CFSwapInt32HostToLittle(rate); memcpy(b+24,&n,4); n=CFSwapInt32HostToLittle(rate*2); memcpy(b+28,&n,4);
    v=CFSwapInt16HostToLittle(2); memcpy(b+32,&v,2); v=CFSwapInt16HostToLittle(16); memcpy(b+34,&v,2);
    memcpy(b+36,"data",4); n=CFSwapInt32HostToLittle(bytes); memcpy(b+40,&n,4);
    double base=kind==0 ? 880 : kind==1 ? 660 : kind==2 ? 1046.5 : 784;
    for (uint32_t i=0; i<count; i++) {
        double t=(double)i/rate, phase=2*M_PI*base*(t+0.016*(1-exp(-t*35)));
        double envelope=fmin(1,t/0.006)*exp(-t*11)*fmin(1,(0.42-t)/0.025);
        int16_t sample=(int16_t)(12500*envelope*(sin(phase)+0.22*sin(phase*2.01))/1.22);
        uint16_t little=CFSwapInt16HostToLittle((uint16_t)sample); memcpy(b+44+i*2,&little,2);
    }
    return d;
}

static NSData *PingSound(NSInteger kind) {
    NSData *data=[NSData dataWithContentsOfFile:Asset(@"sounds",Sounds()[kind],@"wav")];
    return data ?: Tone(kind);
}

@interface PingPanel : NSPanel @end
@implementation PingPanel
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

@interface WheelView : NSView
@property NSInteger selected;
@property BOOL heldMode;
@property(copy) void (^releaseHold)(void);
@property(copy) void (^finish)(NSInteger);
@end
@implementation WheelView
- (instancetype)initWithFrame:(NSRect)frame { if ((self=[super initWithFrame:frame])) _selected=-1; return self; }
- (BOOL)acceptsFirstResponder { return YES; }
- (void)updateTrackingAreas {
    for (NSTrackingArea *a in self.trackingAreas.copy) [self removeTrackingArea:a];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingMouseMoved|NSTrackingActiveAlways|NSTrackingInVisibleRect owner:self userInfo:nil]];
    [super updateTrackingAreas];
}
- (void)mouseMoved:(NSEvent *)e { self.selected=Selection([self convertPoint:e.locationInWindow fromView:nil], NSMakePoint(190,206)); self.needsDisplay=YES; }
- (void)mouseDragged:(NSEvent *)e { [self mouseMoved:e]; }
- (void)mouseDown:(NSEvent *)e { [self mouseMoved:e]; }
- (void)mouseUp:(NSEvent *)e { [self mouseMoved:e]; if(!self.heldMode) self.finish(self.selected); }
- (void)rightMouseDown:(NSEvent *)e { (void)e; self.finish(-1); }
- (void)keyDown:(NSEvent *)e {
    if (e.keyCode==53) self.finish(-1);
    else if (e.keyCode==36) self.finish(self.selected);
    else if (e.keyCode>=123 && e.keyCode<=126) {
        self.selected=e.keyCode==123 ? 0 : e.keyCode==124 ? 4 : e.keyCode==125 ? 6 : 2;
        self.needsDisplay=YES;
    }
}
- (void)keyUp:(NSEvent *)e {
    if(e.keyCode==kVK_ANSI_Q && self.heldMode) self.releaseHold();
}
- (void)flagsChanged:(NSEvent *)e {
    if(self.heldMode && !(e.modifierFlags & NSEventModifierFlagOption)) self.releaseHold();
}
- (void)drawRect:(NSRect)dirty {
    (void)dirty; NSPoint c=NSMakePoint(190,206);
    NSShadow *shadow=[NSShadow new];shadow.shadowColor=[NSColor colorWithWhite:0 alpha:0.5];shadow.shadowBlurRadius=12;
    [NSGraphicsContext saveGraphicsState];[shadow set];
    [[NSColor colorWithSRGBRed:0.13 green:0.16 blue:0.17 alpha:0.68] setFill];[Circle(c,158) fill];
    [NSGraphicsContext restoreGraphicsState];
    for (NSInteger i=0;i<8;i++) {
        CGFloat a=180-i*45;
        NSBezierPath *w=[NSBezierPath bezierPath];[w moveToPoint:c];
        [w appendBezierPathWithArcWithCenter:c radius:157 startAngle:a-22.5 endAngle:a+22.5];[w closePath];
        if (i==self.selected) {
            NSGradient *g=[[NSGradient alloc] initWithStartingColor:[NSColor colorWithWhite:0.87 alpha:0.04] endingColor:[NSColor colorWithWhite:0.94 alpha:0.35]];
            [g drawInBezierPath:w relativeCenterPosition:NSZeroPoint];
        }
        CGFloat edge=(a-22.5)*M_PI/180;
        NSBezierPath *line=[NSBezierPath bezierPath];[line moveToPoint:NSMakePoint(c.x+77*cos(edge),c.y+77*sin(edge))];[line lineToPoint:NSMakePoint(c.x+156*cos(edge),c.y+156*sin(edge))];
        [[NSColor colorWithWhite:0.8 alpha:0.16] setStroke];line.lineWidth=0.7;[line stroke];
        CGFloat r=119, size=i==self.selected?49:43;
        NSPoint p=NSMakePoint(c.x+r*cos(a*M_PI/180),c.y+r*sin(a*M_PI/180));
        Art(Textures()[i],NSMakeRect(p.x-size/2,p.y-size/2,size,size),i==self.selected?1:0.91,i!=0);
    }
    StrokeCircle(c,158,[NSColor colorWithWhite:0.6 alpha:0.2],0.8);
    // Nested bevels around a dark teal glass centre.
    [[NSColor colorWithWhite:0.025 alpha:0.95] setFill];[Circle(c,82) fill];
    NSGradient *metal=[[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithSRGBRed:0.23 green:0.17 blue:0.07 alpha:1],0.0,
        [NSColor colorWithSRGBRed:0.97 green:0.88 blue:0.55 alpha:1],0.46,
        [NSColor colorWithSRGBRed:0.50 green:0.38 blue:0.15 alpha:1],0.66,
        [NSColor colorWithSRGBRed:0.91 green:0.80 blue:0.47 alpha:1],1.0,nil];
    [metal drawInBezierPath:Circle(c,79) angle:78];
    [[NSColor colorWithSRGBRed:0.035 green:0.07 blue:0.075 alpha:1] setFill];[Circle(c,75.5) fill];
    NSGradient *glass=[[NSGradient alloc] initWithStartingColor:[NSColor colorWithSRGBRed:0.075 green:0.30 blue:0.32 alpha:0.98] endingColor:[NSColor colorWithSRGBRed:0.025 green:0.115 blue:0.15 alpha:0.97]];
    [glass drawInBezierPath:Circle(c,72.5) relativeCenterPosition:NSMakePoint(-0.35,0.45)];
    StrokeCircle(c,73,[NSColor colorWithSRGBRed:0.77 green:0.68 blue:0.37 alpha:0.72],1);
    StrokeCircle(c,69.5,[NSColor colorWithWhite:0.7 alpha:0.09],0.7);
    Art(@"generic_ping",NSMakeRect(c.x-17,c.y+14,34,34),1,NO);
    Text(@"PING",NSMakePoint(c.x,c.y-4),14,[NSColor colorWithSRGBRed:0.35 green:0.71 blue:0.79 alpha:1],NSFontWeightBold);
    Text(@"⌁  BACK",NSMakePoint(c.x,c.y-43),10,[NSColor colorWithSRGBRed:0.4 green:0.57 blue:0.58 alpha:0.85],NSFontWeightSemibold);
    NSString *hint=self.selected<0?@"按住 ⌥Q 划选 · 松开发送 · Esc 取消":Labels()[self.selected];
    [[NSColor colorWithWhite:0.03 alpha:0.78] setFill];[[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(62,13,256,25) xRadius:12 yRadius:12] fill];
    Text(hint,NSMakePoint(190,26),11,[NSColor colorWithWhite:0.88 alpha:0.9],NSFontWeightMedium);
}

@end

@interface MarkView : NSView
@property NSInteger kind;
@property double progress;
@end
@implementation MarkView
- (void)drawRect:(NSRect)dirty {
    (void)dirty; double t=self.progress;
    CGFloat alpha=t>1.30?fmax(0,(1.8-t)/0.5):1;
    NSColor *color=self.kind==0?Gold():self.kind==2||self.kind==1?[NSColor colorWithSRGBRed:1 green:0.3 blue:0.25 alpha:1]:Mint();
    NSPoint c=NSMakePoint(100,78);
    // Fast impact flash followed by two thin ground ripples.
    for (NSInteger i=0;i<2;i++) {
        double u=(t-i*0.13)/0.64;if(u<0||u>1)continue;
        CGFloat r=12+65*(1-pow(1-u,2));
        NSBezierPath *ring=[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(c.x-r,c.y-r*0.42,2*r,2*r*0.42)];
        [[color colorWithAlphaComponent:pow(1-u,1.4)*alpha*0.85] setStroke];ring.lineWidth=1.1+2*(1-u);[ring stroke];
    }
    if(t<0.16) {
        CGFloat flash=1-t/0.16;
        StrokeCircle(c,6+12*(1-flash),[color colorWithAlphaComponent:flash*0.6],2);
    }
    CGFloat scale=t<0.10?0.55+0.65*(1-pow(1-t/0.1,3)):1+0.20*exp(-(t-0.1)*19)*cos((t-0.1)*24);
    CGFloat lift=t<0.16?10*sin(t/0.16*M_PI):0;
    CGFloat size=86*scale;
    NSRect rect=NSMakeRect(c.x-size/2,c.y-8+lift,size,size);
    NSShadow *shadow=[NSShadow new];shadow.shadowColor=[NSColor colorWithWhite:0 alpha:alpha*0.85];shadow.shadowBlurRadius=5;shadow.shadowOffset=NSMakeSize(0,-2);
    [NSGraphicsContext saveGraphicsState];[shadow set];
    if(self.kind==5) {
        CGFloat split=18*exp(-t*20);
        Art(@"pingwheel_allin_render_01",NSOffsetRect(rect,-split,0),alpha,NO);
        Art(@"pingwheel_allin_render_02",NSOffsetRect(rect,split,0),alpha,NO);
    } else {
        NSString *name=self.kind==3?@"pingwheel_pushrender":self.kind==1?@"pingwheel_enemyvisionrender":Textures()[self.kind];
        Art(name,rect,alpha,NO);
    }
    [NSGraphicsContext restoreGraphicsState];
}

@end

static NSRect DragRect(NSPoint start, NSPoint end, NSRect bounds) {
    NSRect r=NSMakeRect(fmin(start.x,end.x),fmin(start.y,end.y),fabs(end.x-start.x),fabs(end.y-start.y));
    return NSIntersectionRect(r,bounds);
}
static BOOL ValidHighlight(NSRect r) { return r.size.width>=12 && r.size.height>=6; }
static CGFloat EmphasisAlpha(NSTimeInterval age) {
    if(age<0 || age>=6) return 0;
    return age>5.25?(6-age)/0.75:1;
}
static void DrawEmphasis(NSRect rect, CGFloat alpha, BOOL selecting) {
    [[NSColor colorWithSRGBRed:1 green:0.78 blue:0.18 alpha:0.19*alpha] setFill];
    NSBezierPath *shape=[NSBezierPath bezierPathWithRoundedRect:rect xRadius:3 yRadius:3];[shape fill];
    if(selecting) {
        [[NSColor colorWithSRGBRed:0.8 green:0.59 blue:0.12 alpha:0.55] setStroke];
        CGFloat dash[]={4,3};[shape setLineDash:dash count:2 phase:0];shape.lineWidth=1;[shape stroke];
    }
}
@interface EmphasisView : NSView
@property CGFloat strength;
@end
@implementation EmphasisView
- (void)drawRect:(NSRect)dirty { (void)dirty;DrawEmphasis(NSInsetRect(self.bounds,1,1),self.strength,NO); }
@end

@interface SelectionView : NSView
@property NSPoint start;
@property NSRect selection;
@property BOOL dragging;
@property(copy) void (^complete)(NSRect);
@property(copy) void (^cancel)(void);
@end
@implementation SelectionView
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { (void)event;return YES; }
- (void)resetCursorRects { [self addCursorRect:self.bounds cursor:NSCursor.crosshairCursor]; }
- (void)mouseDown:(NSEvent *)event {
    self.start=[self convertPoint:event.locationInWindow fromView:nil];self.dragging=YES;
    self.selection=NSMakeRect(self.start.x,self.start.y,0,0);self.needsDisplay=YES;
}
- (void)mouseDragged:(NSEvent *)event {
    if(!self.dragging)return;
    self.selection=DragRect(self.start,[self convertPoint:event.locationInWindow fromView:nil],self.bounds);self.needsDisplay=YES;
}
- (void)mouseUp:(NSEvent *)event {
    if(!self.dragging)return;
    [self mouseDragged:event];self.dragging=NO;
    if(ValidHighlight(self.selection))self.complete(self.selection);else self.cancel();
}
- (void)rightMouseDown:(NSEvent *)event { (void)event;self.cancel(); }
- (void)keyDown:(NSEvent *)event { if(event.keyCode==kVK_Escape)self.cancel(); }
- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    // An almost transparent hit surface; the document remains undimmed.
    [[NSColor colorWithWhite:1 alpha:0.01] setFill];NSRectFill(self.bounds);
    if(self.dragging)DrawEmphasis(self.selection,1,YES);
    CGFloat width=fmin(390,self.bounds.size.width-20);
    NSRect hint=NSMakeRect((self.bounds.size.width-width)/2,self.bounds.size.height-60,width,32);
    [[NSColor colorWithWhite:0.08 alpha:0.88] setFill];[[NSBezierPath bezierPathWithRoundedRect:hint xRadius:16 yRadius:16] fill];
    Text(@"拖框强调这句话 · 松开打问号 · Esc 取消",NSMakePoint(NSMidX(hint),NSMidY(hint)),12,[NSColor colorWithWhite:0.94 alpha:1],NSFontWeightMedium);
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    HoldState _holdState;
}
@property NSStatusItem *status;
@property PingPanel *wheel;
@property WheelView *wheelView;
@property NSTimer *wheelTimer;
@property NSPoint lastWheelMouse;
@property NSPoint anchor;
@property NSMutableArray<NSPanel *> *marks;
@property NSMutableArray<AVAudioPlayer *> *players;
@property NSRunningApplication *previousApp;
@property EventHotKeyRef hotKey;
@property EventHotKeyRef questionKey;
@property EventHotKeyRef highlightKey;
@property EventHotKeyRef clearKey;
@property BOOL highlightKeyDown;
@property PingPanel *selectionPanel;
@property NSTimer *selectionTimeout;
@property NSPanel *emphasisPanel;
@property NSTimer *emphasisTimer;
@property BOOL muted;
@property NSTimeInterval lastPing;
@property NSMenuItem *muteItem;
- (void)showWheelHeld:(BOOL)held;
- (void)beginHighlight;
- (void)cancelSelection;
- (void)clearHighlights;
- (void)commitHighlight:(NSRect)rect onScreen:(NSRect)screen;
- (void)beginHeldWheel;
- (void)releaseHeldWheel;
- (BOOL)playSound:(NSInteger)kind;
- (void)finish:(NSInteger)kind;
- (void)sendPing:(NSInteger)kind at:(NSPoint)point;
@end
static OSStatus HotKeyHandler(EventHandlerCallRef next, EventRef event, void *data) {
    (void)next; EventHotKeyID key; GetEventParameter(event,kEventParamDirectObject,typeEventHotKeyID,NULL,sizeof(key),NULL,&key);
    AppDelegate *app=(__bridge AppDelegate *)data;
    if (key.id==1) {
        if(GetEventKind(event)==kEventHotKeyPressed) [app beginHeldWheel];
        else [app releaseHeldWheel];
    } else if(key.id==3) {
        if(GetEventKind(event)==kEventHotKeyReleased)app.highlightKeyDown=NO;
        else if(!app.highlightKeyDown) { app.highlightKeyDown=YES;[app beginHighlight]; }
    } else if(key.id==4 && GetEventKind(event)==kEventHotKeyPressed) [app clearHighlights];
    else if(key.id==2 && GetEventKind(event)==kEventHotKeyPressed) { [app cancelSelection];[app sendPing:0 at:NSEvent.mouseLocation]; }
    return noErr;
}
@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    (void)note; self.marks=[NSMutableArray new]; self.players=[NSMutableArray new];
    self.muted=[[NSUserDefaults standardUserDefaults] boolForKey:@"muted"];
    self.status=[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSImage *statusIcon=[Texture(@"enemy_missing") copy];
    statusIcon.size=NSMakeSize(22,22);statusIcon.template=NO;
    self.status.button.image=statusIcon;
    self.status.button.title=statusIcon?@"":@"?";
    self.status.button.imagePosition=NSImageOnly;
    self.status.button.toolTip=@"PingTogether · 本地桌面标记";
    NSMenu *menu=[NSMenu new];
    NSMenuItem *title=[[NSMenuItem alloc] initWithTitle:@"PingTogether · 本地版" action:NULL keyEquivalent:@""]; [menu addItem:title];
    [menu addItem:NSMenuItem.separatorItem];
    for (NSArray *entry in @[@[@"打开轮盘    按住 ⌥Q",NSStringFromSelector(@selector(openFromMenu))],@[@"框选并打问号    ⌥A",NSStringFromSelector(@selector(openHighlightFromMenu))],@[@"清除强调    ⌥X",NSStringFromSelector(@selector(clearHighlights))],@[@"演示问号",NSStringFromSelector(@selector(demo))],@[@"测试提示音",NSStringFromSelector(@selector(testSound))],@[@"静音",NSStringFromSelector(@selector(toggleMute))],@[@"使用说明",NSStringFromSelector(@selector(help))],@[@"退出 PingTogether",NSStringFromSelector(@selector(quit))]]) {
        NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:entry[0] action:NSSelectorFromString(entry[1]) keyEquivalent:@""]; item.target=self; [menu addItem:item];
        if ([entry[0] isEqual:@"静音"]) { self.muteItem=item; item.state=self.muted?NSControlStateValueOn:NSControlStateValueOff; }
    }
    self.status.menu=menu;
    EventTypeSpec events[]={{kEventClassKeyboard,kEventHotKeyPressed},{kEventClassKeyboard,kEventHotKeyReleased}};
    InstallApplicationEventHandler(HotKeyHandler,2,events,(__bridge void *)self,NULL);
    EventHotKeyID wheelID={'PIng',1}, questionID={'PIng',2}, highlightID={'PIng',3}, clearID={'PIng',4};
    OSStatus a=RegisterEventHotKey(kVK_ANSI_Q,optionKey,wheelID,GetApplicationEventTarget(),0,&_hotKey);
    OSStatus b=RegisterEventHotKey(kVK_ANSI_Q,controlKey|optionKey,questionID,GetApplicationEventTarget(),0,&_questionKey);
    OSStatus c=RegisterEventHotKey(kVK_ANSI_A,optionKey,highlightID,GetApplicationEventTarget(),0,&_highlightKey);
    OSStatus d=RegisterEventHotKey(kVK_ANSI_X,optionKey,clearID,GetApplicationEventTarget(),0,&_clearKey);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
    if (a!=noErr || b!=noErr || c!=noErr || d!=noErr) { NSAlert *alert=[NSAlert new]; alert.messageText=@"快捷键注册失败"; alert.informativeText=@"快捷键可能被其他应用占用。你仍可通过菜单栏打开轮盘。"; [alert runModal]; }
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"hasLaunched"]) { [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasLaunched"]; [self help]; }
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--preview"]) [self openFromMenu];
}
- (void)openHighlightFromMenu {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ [self beginHighlight]; });
}
- (void)beginHighlight {
    if(self.selectionPanel) { [self cancelSelection];return; }
    [self finish:-1];
    NSScreen *screen=NSScreen.mainScreen;
    for(NSScreen *candidate in NSScreen.screens)if(NSPointInRect(NSEvent.mouseLocation,candidate.frame))screen=candidate;
    NSRect frame=screen.frame;
    self.selectionPanel=[[PingPanel alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
    self.selectionPanel.title=@"PingTogether 框选强调";
    self.selectionPanel.opaque=NO;self.selectionPanel.backgroundColor=NSColor.clearColor;self.selectionPanel.hasShadow=NO;
    self.selectionPanel.level=NSPopUpMenuWindowLevel;
    self.selectionPanel.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.selectionPanel.hidesOnDeactivate=NO;
    SelectionView *view=[[SelectionView alloc] initWithFrame:NSMakeRect(0,0,frame.size.width,frame.size.height)];
    __weak AppDelegate *weak=self;
    view.cancel=^{ [weak cancelSelection]; };
    view.complete=^(NSRect rect) {
        AppDelegate *owner=weak;if(!owner.selectionPanel)return;
        NSRect global=[owner.selectionPanel convertRectToScreen:rect];
        [owner cancelSelection];[owner commitHighlight:global onScreen:frame];
    };
    self.selectionPanel.contentView=view;
    [self.selectionPanel makeKeyAndOrderFront:nil];[self.selectionPanel makeFirstResponder:view];
    [self.selectionPanel invalidateCursorRectsForView:view];[NSCursor.crosshairCursor set];
    self.selectionTimeout=[NSTimer timerWithTimeInterval:30 repeats:NO block:^(NSTimer *timer) {
        (void)timer;[weak cancelSelection];
    }];[[NSRunLoop mainRunLoop] addTimer:self.selectionTimeout forMode:NSRunLoopCommonModes];
}
- (void)cancelSelection {
    [self.selectionTimeout invalidate];self.selectionTimeout=nil;
    if(self.selectionPanel) { [self.selectionPanel orderOut:nil];self.selectionPanel=nil;[NSCursor.arrowCursor set]; }
}
- (void)clearHighlights {
    [self cancelSelection];[self.emphasisTimer invalidate];self.emphasisTimer=nil;
    [self.emphasisPanel orderOut:nil];self.emphasisPanel=nil;
}
- (void)screenChanged:(NSNotification *)notification { (void)notification;[self clearHighlights]; }
- (void)commitHighlight:(NSRect)rect onScreen:(NSRect)screen {
    rect=NSIntersectionRect(rect,screen);if(!ValidHighlight(rect))return;
    [self clearHighlights];
    NSPanel *panel=[[NSPanel alloc] initWithContentRect:NSInsetRect(rect,-1,-1) styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
    panel.opaque=NO;panel.backgroundColor=NSColor.clearColor;panel.hasShadow=NO;panel.ignoresMouseEvents=YES;
    panel.level=NSPopUpMenuWindowLevel-1;panel.hidesOnDeactivate=NO;
    panel.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary;
    EmphasisView *view=[[EmphasisView alloc] initWithFrame:NSMakeRect(0,0,rect.size.width+2,rect.size.height+2)];view.strength=1;
    panel.contentView=view;self.emphasisPanel=panel;[panel orderFrontRegardless];
    NSTimeInterval start=NSProcessInfo.processInfo.systemUptime;
    __weak AppDelegate *weak=self;
    self.emphasisTimer=[NSTimer timerWithTimeInterval:1.0/30 repeats:YES block:^(NSTimer *timer) {
        NSTimeInterval age=NSProcessInfo.processInfo.systemUptime-start;
        if(age>=6) { [timer invalidate];[panel orderOut:nil];
            if(weak.emphasisPanel==panel) { weak.emphasisPanel=nil;weak.emphasisTimer=nil; }return;
        }
        view.strength=EmphasisAlpha(age);view.needsDisplay=YES;
    }];[[NSRunLoop mainRunLoop] addTimer:self.emphasisTimer forMode:NSRunLoopCommonModes];
    // Prefer the right margin, leaving the highlighted sentence readable.
    CGFloat x=NSMaxX(rect)+36;
    if(x>NSMaxX(screen)-90)x=NSMinX(rect)-36;
    x=fmax(NSMinX(screen)+90,fmin(x,NSMaxX(screen)-90));
    CGFloat y=fmax(NSMinY(screen)+78,fmin(NSMidY(rect),NSMaxY(screen)-122));
    [self sendPing:0 at:NSMakePoint(x,y)];
}
- (void)openFromMenu { dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ [self showWheelHeld:NO]; }); }
- (void)beginHeldWheel {
    if(!BeginHold(&_holdState)) return;
    if(self.wheel) [self finish:-1];
    _holdState.wheel=YES;
    [self showWheelHeld:YES];
}
- (void)releaseHeldWheel {
    if(!EndHold(&_holdState) || !self.wheel || !self.wheelView.heldMode) return;
    // Re-evaluate at release, rather than trusting the preceding timer frame.
    NSPoint current=NSEvent.mouseLocation;
    NSPoint local=NSMakePoint(current.x-self.wheel.frame.origin.x,current.y-self.wheel.frame.origin.y);
    [self finish:Selection(local,NSMakePoint(190,206))];
}
- (void)showWheelHeld:(BOOL)held {
    [self cancelSelection];
    if (self.wheel) { [self finish:-1]; return; }
    self.previousApp=NSWorkspace.sharedWorkspace.frontmostApplication;
    self.anchor=NSEvent.mouseLocation;
    // Keep the wheel origin exactly at the pointer, including near screen edges.
    CGFloat x=self.anchor.x-190, y=self.anchor.y-206;
    self.wheel=[[PingPanel alloc] initWithContentRect:NSMakeRect(x,y,380,390) styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
    self.wheel.opaque=NO; self.wheel.backgroundColor=NSColor.clearColor; self.wheel.hasShadow=NO;
    self.wheel.level=NSPopUpMenuWindowLevel; self.wheel.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.wheel.hidesOnDeactivate=NO; self.wheel.acceptsMouseMovedEvents=YES;
    self.wheel.title=@"PingTogether 轮盘";
    self.wheelView=[[WheelView alloc] initWithFrame:NSMakeRect(0,0,380,390)];
    self.wheelView.heldMode=held;
    __weak AppDelegate *weak=self;
    self.wheelView.finish=^(NSInteger kind) { [weak finish:kind]; };
    self.wheelView.releaseHold=^{ [weak releaseHeldWheel]; };
    self.wheel.contentView=self.wheelView; [self.wheel makeKeyAndOrderFront:nil]; [self.wheel makeFirstResponder:self.wheelView];
    self.lastWheelMouse=NSEvent.mouseLocation;
    // Read the pointer even beyond the panel, so long directional swipes work.
    self.wheelTimer=[NSTimer timerWithTimeInterval:1.0/60 repeats:YES block:^(NSTimer *timer) {
        AppDelegate *owner=weak;
        if (!owner.wheel) { [timer invalidate];return; }
        NSPoint current=NSEvent.mouseLocation;
        if (!NSEqualPoints(current,owner.lastWheelMouse)) {
            owner.lastWheelMouse=current;
            NSPoint local=NSMakePoint(current.x-owner.wheel.frame.origin.x,current.y-owner.wheel.frame.origin.y);
            owner.wheelView.selected=Selection(local,NSMakePoint(190,206));
            owner.wheelView.needsDisplay=YES;
        }
        BOOL chordDown=CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,kVK_ANSI_Q) && (CGEventSourceFlagsState(kCGEventSourceStateCombinedSessionState)&kCGEventFlagMaskAlternate);
        if(owner.wheelView.heldMode && !chordDown) [owner releaseHeldWheel];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.wheelTimer forMode:NSRunLoopCommonModes];
}
- (void)finish:(NSInteger)kind {
    if (!self.wheel) return;
    CancelHold(&_holdState);
    [self.wheelTimer invalidate];self.wheelTimer=nil;
    [self.wheel orderOut:nil]; self.wheel=nil; self.wheelView=nil;
    if (kind>=0) [self sendPing:kind at:self.anchor];
    self.previousApp=nil;
}
- (void)sendPing:(NSInteger)kind at:(NSPoint)point {
    if (kind<0 || kind>=8) return;
    NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    if (now-self.lastPing<0.12) return; self.lastPing=now;
    // One local event per ping. A future transport can consume the same event.
    NSDictionary *event=@{@"version":@1,@"id":NSUUID.UUID.UUIDString,@"kind":@(kind),@"x":@(point.x),@"y":@(point.y),@"timestamp":@(NSDate.date.timeIntervalSince1970)};
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PingTogetherLocalPing" object:self userInfo:event];
    NSPanel *panel=[[NSPanel alloc] initWithContentRect:NSMakeRect(point.x-100,point.y-78,200,200) styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
    panel.opaque=NO; panel.backgroundColor=NSColor.clearColor; panel.hasShadow=NO; panel.ignoresMouseEvents=YES;
    panel.level=NSPopUpMenuWindowLevel; panel.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary; panel.hidesOnDeactivate=NO;
    MarkView *view=[[MarkView alloc] initWithFrame:NSMakeRect(0,0,200,200)]; view.kind=kind; panel.contentView=view;
    [self.marks addObject:panel]; [panel orderFrontRegardless];
    if (self.marks.count>12) { [self.marks.firstObject orderOut:nil]; [self.marks removeObjectAtIndex:0]; }
    __weak AppDelegate *weak=self;
    NSTimer *timer=[NSTimer timerWithTimeInterval:1.0/60 repeats:YES block:^(NSTimer *t) {
        view.progress=NSProcessInfo.processInfo.systemUptime-now;
        if (view.progress>=1.8) { [panel orderOut:nil]; [weak.marks removeObject:panel]; [t invalidate]; }
        else view.needsDisplay=YES;
    }]; [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    if (!self.muted) [self playSound:kind];
}
- (BOOL)playSound:(NSInteger)kind {
    NSIndexSet *finished=[self.players indexesOfObjectsPassingTest:^BOOL(AVAudioPlayer *p, NSUInteger idx, BOOL *stop) { (void)idx; (void)stop; return !p.playing; }];
    [self.players removeObjectsAtIndexes:finished];
    NSError *error=nil;
    AVAudioPlayer *player=[[AVAudioPlayer alloc] initWithData:PingSound(kind) error:&error];
    player.volume=1.0;
    if (!player || ![player prepareToPlay] || ![player play]) {
        NSLog(@"PingTogether playback failed: %@",error ?: @"Audio output could not start");
        self.status.button.toolTip=@"提示音播放失败，可在菜单中测试声音";
        return NO;
    }
    [self.players addObject:player];return YES;
}
- (void)testSound {
    NSString *output=OutputStatus();
    if(self.muted || [output containsString:@"系统已静音"] || [output containsString:@"未检测到"]) {
        NSAlert *alert=[NSAlert new];alert.messageText=@"提示音检查";
        alert.informativeText=[NSString stringWithFormat:@"%@\n\n%@",self.muted?@"应用已静音：取消菜单中的“静音”后重试。":@"应用声音已开启。",output];
        [alert runModal];return;
    }
    if(![self playSound:0]) {
        NSAlert *alert=[NSAlert new];alert.messageText=@"提示音未能启动";alert.informativeText=output;[alert runModal];
    }
}

- (void)demo { NSRect f=NSScreen.mainScreen.frame; [self sendPing:0 at:NSMakePoint(NSMidX(f),NSMidY(f))]; }
- (void)toggleMute { self.muted=!self.muted; self.muteItem.state=self.muted?NSControlStateValueOn:NSControlStateValueOff; [[NSUserDefaults standardUserDefaults] setBool:self.muted forKey:@"muted"]; }
- (void)help {
    NSAlert *a=[NSAlert new]; a.messageText=@"在桌面上，Ping 一下。";
    a.informativeText=@"将鼠标放到想标记的位置。\n\n按住 ⌥ Option + Q：在鼠标位置唤出轮盘\n保持按住，移动鼠标选中标记。\n松开 Q 或 Option：在唤出位置发送并播放提示音。\n停在中心松开取消；不需要点击。\n菜单栏“打开轮盘”仍支持点击选择。\n⌃ Control + ⌥ Option + Q：直接打问号\nEsc / 右键 / 点击中心：取消\n\n⌥ Option + A：进入框选，拖框后松开鼠标\n浅黄底纹保留 6 秒，并自动打问号\n⌥ Option + X：立即清除底纹\n底纹固定在屏幕位置，滚动前可先清除。\n\n标记约 2 秒后消失，不拦截鼠标操作。\n菜单栏 ◉ ? 可以测试提示音、静音和退出。\n\n屏幕共享请选整个屏幕。传递声音需要共享软件开启系统音频。当前版本仅在本机显示。";
    [a addButtonWithTitle:@"开始使用"]; [a runModal];
}
- (void)quit { [NSApp terminate:nil]; }
- (void)applicationWillTerminate:(NSNotification *)n { (void)n; if(self.hotKey) UnregisterEventHotKey(self.hotKey); if(self.questionKey) UnregisterEventHotKey(self.questionKey); if(self.highlightKey) UnregisterEventHotKey(self.highlightKey); if(self.clearKey) UnregisterEventHotKey(self.clearKey);[self clearHighlights]; }
@end

static int SelfTest(void) {
    NSRect bounds=NSMakeRect(0,0,1000,800);
    NSRect forward=DragRect(NSMakePoint(20,30),NSMakePoint(400,60),bounds);
    NSRect reverse=DragRect(NSMakePoint(400,60),NSMakePoint(20,30),bounds);
    NSCAssert(NSEqualRects(forward,reverse) && ValidHighlight(forward),@"Both drag directions must select the same sentence");
    NSCAssert(!ValidHighlight(DragRect(NSMakePoint(20,30),NSMakePoint(20,30),bounds)),@"An accidental click must not ping");
    NSCAssert(NSEqualRects(DragRect(NSMakePoint(-20,-40),NSMakePoint(50,80),bounds),NSMakeRect(0,0,50,80)),@"Selection must be clipped to its display");
    NSCAssert(EmphasisAlpha(0)==1 && EmphasisAlpha(5)==1 && EmphasisAlpha(5.625)==0.5 && EmphasisAlpha(6)==0,@"Emphasis must remain readable then fade and expire");
    HoldState hold={0};
    NSCAssert(BeginHold(&hold),@"Initial press must open");
    NSCAssert(!BeginHold(&hold),@"Key repeat must not reopen");
    NSCAssert(EndHold(&hold),@"Release must consume the open wheel");
    NSCAssert(!EndHold(&hold),@"Multiple release paths must not send twice");
    NSCAssert(BeginHold(&hold),@"Next gesture must open");CancelHold(&hold);
    NSCAssert(!BeginHold(&hold),@"Escape while held must suppress repeat");
    NSCAssert(!EndHold(&hold),@"Release after escape must not send");
    NSCAssert(BeginHold(&hold),@"A new press after cancellation must work");EndHold(&hold);
    NSPoint c=NSMakePoint(190,206);
    NSCAssert(Selection(c,c)==-1,@"Center must cancel");
    NSCAssert(Selection(NSMakePoint(c.x+81,c.y),c)==-1,@"Entire hub must cancel");
    for (NSInteger k=0;k<8;k++) {
        double a=(180-k*45)*M_PI/180;
        NSCAssert(Selection(NSMakePoint(c.x+115*cos(a),c.y+115*sin(a)),c)==k,@"Eight-way selection must match artwork");
        NSData *data=[NSData dataWithContentsOfFile:Asset(@"sounds",Sounds()[k],@"wav")];
        NSCAssert(data.length>44,@"Bundled original sound must exist");
        NSError *error=nil;AVAudioPlayer *player=[[AVAudioPlayer alloc] initWithData:data error:&error];
        NSCAssert(player && !error && player.duration>0.05,@"Original WAV must decode");
        NSCAssert(Texture(Textures()[k])!=nil,@"Every wheel texture must decode");
    }
    for (NSString *name in @[@"generic_ping",@"pingwheel_pushrender",@"pingwheel_enemyvisionrender",@"pingwheel_allin_render_01",@"pingwheel_allin_render_02"]) NSCAssert(Texture(name)!=nil,@"Animation art must decode");
    puts("PASS: highlight drag/clipping/expiry, hold/release/repeat/cancel state, eight sectors, center cancellation, 8 original WAVs and textures");return 0;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        
        NSApplication *app=NSApplication.sharedApplication; [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        if (argc>1 && strcmp(argv[1],"--self-test")==0) return SelfTest();
        if (argc>1 && strcmp(argv[1],"--test-audio")==0) {
            AppDelegate *tester=[AppDelegate new];tester.players=[NSMutableArray new];
            printf("%s\n",OutputStatus().UTF8String);
            if(![tester playSound:0]) return 1;
            NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:0.25];
            [[NSRunLoop currentRunLoop] runUntilDate:deadline];
            AVAudioPlayer *player=tester.players.firstObject;
            printf("Audio started=%s, playback time=%.3fs, app gain=%.2f\n",player.playing?"YES":"NO",player.currentTime,player.volume);
            BOOL advancing=player.currentTime>0.05;
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
            return advancing?0:1;
        }
        if (argc>2 && strcmp(argv[1],"--render-emphasis")==0) {
            NSImage *preview=[[NSImage alloc] initWithSize:NSMakeSize(760,260)];[preview lockFocus];
            [[NSColor colorWithWhite:0.985 alpha:1] setFill];NSRectFill(NSMakeRect(0,0,760,260));
            Text(@"读到这一句，想和朋友一起讨论",NSMakePoint(380,209),22,NSColor.darkGrayColor,NSFontWeightMedium);
            NSDictionary *attrs=@{NSFontAttributeName:[NSFont systemFontOfSize:16],NSForegroundColorAttributeName:NSColor.blackColor};
            [@"The response depends on the interaction between these two factors." drawAtPoint:NSMakePoint(46,139) withAttributes:attrs];
            DrawEmphasis(NSMakeRect(42,135,538,29),1,NO);
            [@"This observation suggests a different interpretation of the result." drawAtPoint:NSMakePoint(46,101) withAttributes:attrs];
            Art(@"enemy_missing",NSMakeRect(611,129,68,68),1,NO);
            Text(@"⌥A 拖框 + 问号     ·     底纹保留 6 秒     ·     ⌥X 清除",NSMakePoint(380,39),13,NSColor.grayColor,NSFontWeightRegular);
            [preview unlockFocus];
            NSBitmapImageRep *bitmap=[NSBitmapImageRep imageRepWithData:preview.TIFFRepresentation];
            return [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES]?0:1;
        }
        if (argc>2 && strcmp(argv[1],"--render-preview")==0) {
            WheelView *view=[[WheelView alloc] initWithFrame:NSMakeRect(0,0,380,390)]; view.selected=0;
            NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
            [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
            NSData *png=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            return [png writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES]?0:1;
        }
        if (argc>3 && strcmp(argv[1],"--render-mark")==0) {
            MarkView *view=[[MarkView alloc] initWithFrame:NSMakeRect(0,0,200,200)];view.kind=0;view.progress=atof(argv[3]);
            NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];[view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
            return [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES]?0:1;
        }
        AppDelegate *delegate=[AppDelegate new]; app.delegate=delegate; [app run];
    } return 0;
}
