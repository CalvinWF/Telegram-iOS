import Foundation
import UIKit
import SwiftSignalKit
import Display
import TelegramCore
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import AccountContext
import ContextUI
import ShareController
import UndoUI
import BundleIconComponent
import TelegramUIPreferences
import OpenInExternalAppUI
import MultilineTextComponent
import MinimizedContainer
import InstantPageUI
import NavigationStackComponent

private let settingsTag = GenericComponentViewTag()

private final class BrowserScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let contentState: BrowserContentState?
    let presentationState: BrowserPresentationState
    let performAction: ActionSlot<BrowserScreen.Action>
    let performHoldAction: (UIView, ContextGesture?, BrowserScreen.Action) -> Void
    let panelCollapseFraction: CGFloat
    
    init(
        context: AccountContext,
        contentState: BrowserContentState?,
        presentationState: BrowserPresentationState,
        performAction: ActionSlot<BrowserScreen.Action>,
        performHoldAction: @escaping (UIView, ContextGesture?, BrowserScreen.Action) -> Void,
        panelCollapseFraction: CGFloat
    ) {
        self.context = context
        self.contentState = contentState
        self.presentationState = presentationState
        self.performAction = performAction
        self.performHoldAction = performHoldAction
        self.panelCollapseFraction = panelCollapseFraction
    }
    
    static func ==(lhs: BrowserScreenComponent, rhs: BrowserScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.contentState != rhs.contentState {
            return false
        }
        if lhs.presentationState != rhs.presentationState {
            return false
        }
        if lhs.panelCollapseFraction != rhs.panelCollapseFraction {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let navigationBar = Child(BrowserNavigationBarComponent.self)
        let toolbar = Child(BrowserToolbarComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let performAction = context.component.performAction
            let performHoldAction = context.component.performHoldAction
            
            let navigationContent: AnyComponentWithIdentity<Empty>?
            var navigationLeftItems: [AnyComponentWithIdentity<Empty>]
            var navigationRightItems: [AnyComponentWithIdentity<Empty>]
            if context.component.presentationState.isSearching {
                navigationContent = AnyComponentWithIdentity(
                    id: "search",
                    component: AnyComponent(
                        SearchBarContentComponent(
                            theme: environment.theme,
                            strings: environment.strings,
                            performAction: performAction
                        )
                    )
                )
                navigationLeftItems = []
                navigationRightItems = []
            } else {
                let title = context.component.contentState?.title ?? ""
                navigationContent = AnyComponentWithIdentity(
                    id: "title_\(title)",
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: title, font: Font.bold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor, paragraphAlignment: .center)), horizontalAlignment: .center, maximumNumberOfLines: 1)
                    )
                )
                navigationLeftItems = [
                    AnyComponentWithIdentity(
                        id: "close",
                        component: AnyComponent(
                            Button(
                                content: AnyComponent(
                                    MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Common_Close, font: Font.regular(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor, paragraphAlignment: .center)), horizontalAlignment: .left, maximumNumberOfLines: 1)
                                ),
                                action: {
                                    performAction.invoke(.close)
                                }
                            )
                        )
                    )
                ]
                
                let isLoading = (context.component.contentState?.estimatedProgress ?? 1.0) < 1.0
                navigationRightItems = [
                    AnyComponentWithIdentity(
                        id: "settings",
                        component: AnyComponent(
                            ReferenceButtonComponent(
                                content: AnyComponent(
                                    BundleIconComponent(
                                        name: "Instant View/Settings",
                                        tintColor: environment.theme.rootController.navigationBar.primaryTextColor
                                    )
                                ),
                                tag: settingsTag,
                                action: {
                                    performAction.invoke(.openSettings)
                                }
                            )
                        )
                    )
                ]
                if case .webPage = context.component.contentState?.contentType {
                    navigationRightItems.insert(
                        AnyComponentWithIdentity(
                            id: isLoading ? "stop" : "reload",
                            component: AnyComponent(
                                ReferenceButtonComponent(
                                    content: AnyComponent(
                                        BundleIconComponent(
                                            name: isLoading ? "Instant View/CloseIcon" : "Chat/Context Menu/Reload",
                                            tintColor: environment.theme.rootController.navigationBar.primaryTextColor
                                        )
                                    ),
                                    tag: settingsTag,
                                    action: {
                                        performAction.invoke(isLoading ? .stop : .reload)
                                    }
                                )
                            )
                        ),
                        at: 0
                    )
                }
            }
            
            let collapseFraction = context.component.presentationState.isSearching ? 0.0 : context.component.panelCollapseFraction
            
            let navigationBar = navigationBar.update(
                component: BrowserNavigationBarComponent(
                    backgroundColor: environment.theme.rootController.navigationBar.blurredBackgroundColor,
                    separatorColor: environment.theme.rootController.navigationBar.separatorColor,
                    textColor: environment.theme.rootController.navigationBar.primaryTextColor,
                    progressColor: environment.theme.rootController.navigationBar.segmentedBackgroundColor,
                    accentColor: environment.theme.rootController.navigationBar.accentTextColor,
                    topInset: environment.statusBarHeight,
                    height: environment.navigationHeight - environment.statusBarHeight,
                    sideInset: environment.safeInsets.left,
                    leftItems: navigationLeftItems,
                    rightItems: navigationRightItems,
                    centerItem: navigationContent,
                    readingProgress: context.component.contentState?.readingProgress ?? 0.0,
                    loadingProgress: context.component.contentState?.estimatedProgress,
                    collapseFraction: collapseFraction
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(navigationBar
                .position(CGPoint(x: context.availableSize.width / 2.0, y: navigationBar.size.height / 2.0))
            )
            
            let toolbarContent: AnyComponentWithIdentity<Empty>?
            if context.component.presentationState.isSearching {
                toolbarContent = AnyComponentWithIdentity(
                    id: "search",
                    component: AnyComponent(
                        SearchToolbarContentComponent(
                            strings: environment.strings,
                            textColor: environment.theme.rootController.navigationBar.primaryTextColor,
                            index: context.component.presentationState.searchResultIndex,
                            count: context.component.presentationState.searchResultCount,
                            isEmpty: context.component.presentationState.searchQueryIsEmpty,
                            performAction: performAction
                        )
                    )
                )
            } else {
                toolbarContent = AnyComponentWithIdentity(
                    id: "navigation",
                    component: AnyComponent(
                        NavigationToolbarContentComponent(
                            textColor: environment.theme.rootController.navigationBar.primaryTextColor,
                            canGoBack: context.component.contentState?.canGoBack ?? false,
                            canGoForward: context.component.contentState?.canGoForward ?? false,
                            performAction: performAction,
                            performHoldAction: performHoldAction
                        )
                    )
                )
            }
            
            let toolbarBottomInset: CGFloat
            if context.component.presentationState.isSearching && environment.inputHeight > 0.0 {
                toolbarBottomInset = environment.inputHeight
            } else {
                toolbarBottomInset = environment.safeInsets.bottom
            }
            
            let toolbar = toolbar.update(
                component: BrowserToolbarComponent(
                    backgroundColor: environment.theme.rootController.navigationBar.blurredBackgroundColor,
                    separatorColor: environment.theme.rootController.navigationBar.separatorColor,
                    textColor: environment.theme.rootController.navigationBar.primaryTextColor,
                    bottomInset: toolbarBottomInset,
                    sideInset: environment.safeInsets.left,
                    item: toolbarContent,
                    collapseFraction: collapseFraction
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(toolbar
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - toolbar.size.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

struct BrowserPresentationState: Equatable {
    var fontSize: Int32
    var fontIsSerif: Bool
    var isSearching: Bool
    var searchResultIndex: Int
    var searchResultCount: Int
    var searchQueryIsEmpty: Bool
}

public class BrowserScreen: ViewController, MinimizableController {
    enum Action {
        case close
        case reload
        case stop
        case navigateBack
        case navigateForward
        case share
        case minimize
        case openIn
        case openSettings
        case updateSearchActive(Bool)
        case updateSearchQuery(String)
        case scrollToPreviousSearchResult
        case scrollToNextSearchResult
        case decreaseFontSize
        case increaseFontSize
        case resetFontSize
        case updateFontIsSerif(Bool)
    }

    fileprivate final class Node: ViewControllerTracingNode {
        private weak var controller: BrowserScreen?
        private let context: AccountContext
        
        private let contentContainerView = UIView()
        fileprivate let contentNavigationContainer = ComponentView<Empty>()
        fileprivate var content: [BrowserContent] = []
        
        fileprivate var contentState: BrowserContentState?
        private var contentStateDisposable = MetaDisposable()
        
        private var presentationState: BrowserPresentationState
        
        private let performAction = ActionSlot<BrowserScreen.Action>()
        
        fileprivate let componentHost = ComponentView<ViewControllerComponentContainer.Environment>()
        
        private var presentationData: PresentationData
        private var validLayout: (ContainerViewLayout, CGFloat)?
        
        init(controller: BrowserScreen) {
            self.context = controller.context
            self.controller = controller
            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.presentationState = BrowserPresentationState(fontSize: 100, fontIsSerif: false, isSearching: false, searchResultIndex: 0, searchResultCount: 0, searchQueryIsEmpty: true)
                                                
            super.init()
            
            self.pushContent(controller.subject, transition: .immediate)
             
            self.performAction.connect { [weak self] action in
                guard let self, let content = self.content.last, let url = self.contentState?.url else {
                    return
                }
                switch action {
                case .close:
                    self.controller?.dismiss()
                case .reload:
                    content.reload()
                case .stop:
                    content.stop()
                case .navigateBack:
                    if content.currentState.canGoBack {
                        content.navigateBack()
                    } else {
                        self.popContent(transition: .spring(duration: 0.4))
                    }
                case .navigateForward:
                    content.navigateForward()
                case .share:
                    let presentationData = self.presentationData
                    let shareController = ShareController(context: self.context, subject: .url(url))
                    shareController.actionCompleted = { [weak self] in
                        self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                    }
                    self.controller?.present(shareController, in: .window(.root))
                case .minimize:
                    self.minimize()
                case .openIn:
                    self.context.sharedContext.applicationBindings.openUrl(url)
                case .openSettings:
                    self.openSettings()
                case let .updateSearchActive(active):
                    self.updatePresentationState(animated: true, { state in
                        var updatedState = state
                        updatedState.isSearching = active
                        updatedState.searchQueryIsEmpty = true
                        return updatedState
                    })
                    if !active {
                        content.setSearch(nil, completion: nil)
                    }
                case let .updateSearchQuery(query):
                    content.setSearch(query, completion: { [weak self] count in
                        self?.updatePresentationState({ state in
                            var updatedState = state
                            updatedState.searchResultIndex = 0
                            updatedState.searchResultCount = count
                            updatedState.searchQueryIsEmpty = query.isEmpty
                            return updatedState
                        })
                    })
                case .scrollToPreviousSearchResult:
                    content.scrollToPreviousSearchResult(completion: { [weak self] index, count in
                        self?.updatePresentationState({ state in
                            var updatedState = state
                            updatedState.searchResultIndex = index
                            updatedState.searchResultCount = count
                            return updatedState
                        })
                    })
                case .scrollToNextSearchResult:
                    content.scrollToNextSearchResult(completion: { [weak self] index, count in
                        self?.updatePresentationState({ state in
                            var updatedState = state
                            updatedState.searchResultIndex = index
                            updatedState.searchResultCount = count
                            return updatedState
                        })
                    })
                case .decreaseFontSize:
                    self.updatePresentationState({ state in
                        var updatedState = state
                        switch state.fontSize {
                        case 150:
                            updatedState.fontSize = 125
                        case 125:
                            updatedState.fontSize = 115
                        case 115:
                            updatedState.fontSize = 100
                        case 100:
                            updatedState.fontSize = 85
                        case 85:
                            updatedState.fontSize = 75
                        case 75:
                            updatedState.fontSize = 50
                        default:
                            updatedState.fontSize = 50
                        }
                        return updatedState
                    })
                    content.setFontSize(CGFloat(self.presentationState.fontSize) / 100.0)
                case .increaseFontSize:
                    self.updatePresentationState({ state in
                        var updatedState = state
                        switch state.fontSize {
                        case 125:
                            updatedState.fontSize = 150
                        case 115:
                            updatedState.fontSize = 125
                        case 100:
                            updatedState.fontSize = 115
                        case 85:
                            updatedState.fontSize = 100
                        case 75:
                            updatedState.fontSize = 85
                        case 50:
                            updatedState.fontSize = 75
                        default:
                            updatedState.fontSize = 150
                        }
                        return updatedState
                    })
                    content.setFontSize(CGFloat(self.presentationState.fontSize) / 100.0)
                case .resetFontSize:
                    self.updatePresentationState({ state in
                        var updatedState = state
                        updatedState.fontSize = 100
                        return updatedState
                    })
                    content.setFontSize(CGFloat(self.presentationState.fontSize) / 100.0)
                case let .updateFontIsSerif(value):
                    self.updatePresentationState({ state in
                        var updatedState = state
                        updatedState.fontIsSerif = value
                        return updatedState
                    })
                    content.setForceSerif(value)
                }
            }
        }
        
        deinit {
            self.contentStateDisposable.dispose()
        }
        
        override func didLoad() {
            super.didLoad()
            
            self.contentContainerView.clipsToBounds = true
            self.view.addSubview(self.contentContainerView)
        }
        
        func updatePresentationState(animated: Bool = false, _ f: (BrowserPresentationState) -> BrowserPresentationState) {
            self.presentationState = f(self.presentationState)
            self.requestLayout(transition: animated ? .easeInOut(duration: 0.2) : .immediate)
        }

        func pushContent(_ content: BrowserScreen.Subject, transition: ComponentTransition) {
            let browserContent: BrowserContent
            switch content {
            case let .webPage(url):
                browserContent = BrowserWebContent(context: self.context, url: url)
            case let .instantPage(webPage, anchor, sourceLocation):
                let instantPageContent = BrowserInstantPageContent(context: self.context, webPage: webPage, anchor: anchor, url: webPage.content.url ?? "", sourceLocation: sourceLocation)
                instantPageContent.openPeer = { [weak self] peer in
                    guard let self else {
                        return
                    }
                    self.openPeer(peer)
                }
                browserContent = instantPageContent
            }
            browserContent.pushContent = { [weak self] content in
                guard let self else {
                    return
                }
                self.pushContent(content, transition: .spring(duration: 0.4))
            }
            browserContent.present = { [weak self] c, a in
                guard let self, let controller = self.controller else {
                    return
                }
                controller.present(c, in: .window(.root), with: a)
            }
            browserContent.presentInGlobalOverlay = { [weak self] c in
                guard let self, let controller = self.controller else {
                    return
                }
                controller.presentInGlobalOverlay(c)
            }
            browserContent.getNavigationController = { [weak self] in
                return self?.controller?.navigationController as? NavigationController
            }
            browserContent.minimize = { [weak self] in
                guard let self else {
                    return
                }
                self.minimize()
            }
            
            self.content.append(browserContent)
            self.requestLayout(transition: transition)
            
            self.setupContentStateUpdates()
        }
        
        func popContent(transition: ComponentTransition) {
            self.content.removeLast()
            self.requestLayout(transition: transition)
            
            self.setupContentStateUpdates()
        }
        
        func openPeer(_ peer: EnginePeer) {
            guard let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            self.minimize()
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), animated: true))
        }
        
        private func setupContentStateUpdates() {
            for content in self.content {
                content.onScrollingUpdate = { _ in }
            }
            
            guard let content = self.content.last else {
                self.controller?.title = ""
                self.contentState = nil
                self.contentStateDisposable.set(nil)
                self.requestLayout(transition: .easeInOut(duration: 0.25))
                return
            }
            
            var previousState = BrowserContentState(title: "", url: "", estimatedProgress: 1.0, readingProgress: 0.0, contentType: .webPage, canGoBack: false, canGoForward: false, backList: [], forwardList: [])
            if self.content.count > 1 {
                for content in self.content.prefix(upTo: self.content.count - 1) {
                    var backList = previousState.backList
                    backList.append(BrowserContentState.HistoryItem(url: content.currentState.url, title: content.currentState.title, uuid: content.uuid))
                    previousState = previousState.withUpdatedBackList(backList)
                }
            }
            
            self.contentStateDisposable.set((content.state
            |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                guard let self else {
                    return
                }
                var backList = state.backList
                backList.insert(contentsOf: previousState.backList, at: 0)
                
                var canGoBack = state.canGoBack
                if !backList.isEmpty {
                    canGoBack = true
                }
                
                let previousState = self.contentState
                let state = state.withUpdatedCanGoBack(canGoBack).withUpdatedBackList(backList)
                self.controller?.title = state.title
                self.contentState = state
                
                let transition: ComponentTransition
                if let previousState, previousState.withUpdatedReadingProgress(state.readingProgress) == state {
                    transition = .immediate
                } else {
                    transition = .easeInOut(duration: 0.25)
                }
                
                self.requestLayout(transition: transition)
            }))
                        
            content.onScrollingUpdate = { [weak self] update in
                self?.onContentScrollingUpdate(update)
            }
        }
        
        func minimize() {
            guard let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            navigationController.minimizeViewController(controller, damping: nil, beforeMaximize: { _, completion in
                completion()
            }, setupContainer: { [weak self] current in
                let minimizedContainer: MinimizedContainerImpl?
                if let current = current as? MinimizedContainerImpl {
                    minimizedContainer = current
                } else if let context = self?.controller?.context {
                    minimizedContainer = MinimizedContainerImpl(sharedContext: context.sharedContext)
                } else {
                    minimizedContainer = nil
                }
                return minimizedContainer
            }, animated: true)
        }
        
        func openSettings() {
            guard let referenceView = self.componentHost.findTaggedView(tag: settingsTag) as? ReferenceButtonComponent.View else {
                return
            }

            self.view.endEditing(true)
            
            let checkIcon: (PresentationTheme) -> UIImage? = { theme in return generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings/Check"), color: theme.contextMenu.primaryColor) }
            let emptyIcon: (PresentationTheme) -> UIImage? = { _ in
                return nil
            }
            
            let settings = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.webBrowserSettings])
            |> take(1)
            |> map { sharedData -> WebBrowserSettings in
                if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.webBrowserSettings]?.get(WebBrowserSettings.self) {
                    return current
                } else {
                    return WebBrowserSettings.defaultSettings
                }
            }
            
            let _ = (settings
            |> deliverOnMainQueue).start(next: { [weak self] settings in
                guard let self, let controller = self.controller else {
                    return
                }
                
                let source: ContextContentSource = .reference(BrowserReferenceContentSource(controller: controller, sourceView: referenceView.referenceNode.view))
                
                let performAction = self.performAction
                
                let forceIsSerif = self.presentationState.fontIsSerif
                let fontItem = BrowserFontSizeContextMenuItem(
                    value: self.presentationState.fontSize,
                    decrease: { [weak self] in
                        performAction.invoke(.decreaseFontSize)
                        if let self {
                            return self.presentationState.fontSize
                        } else {
                            return 100
                        }
                    }, increase: { [weak self] in
                        performAction.invoke(.increaseFontSize)
                        if let self {
                            return self.presentationState.fontSize
                        } else {
                            return 100
                        }
                    }, reset: {
                        performAction.invoke(.resetFontSize)
                    }
                )
                
                var defaultWebBrowser: String? = settings.defaultWebBrowser
                if defaultWebBrowser == nil || defaultWebBrowser == "inAppSafari" {
                    defaultWebBrowser = "safari"
                }
                
                let url = self.contentState?.url ?? ""
                let openInOptions = availableOpenInOptions(context: self.context, item: .url(url: url))
                let openInTitle: String
                let openInUrl: String
                if let option = openInOptions.first(where: { $0.identifier == defaultWebBrowser }) {
                    openInTitle = option.title
                    if case let .openUrl(url) = option.action() {
                        openInUrl = url
                    } else {
                        openInUrl = url
                    }
                } else {
                    openInTitle = "Safari"
                    openInUrl = url
                }
                
                let items: [ContextMenuItem] = [
                    .custom(fontItem, false),
                    .action(ContextMenuActionItem(text: self.presentationData.strings.InstantPage_FontSanFrancisco, icon: forceIsSerif ? emptyIcon : checkIcon, action: { (controller, action) in
                        performAction.invoke(.updateFontIsSerif(false))
                        action(.default)
                    })), .action(ContextMenuActionItem(text: self.presentationData.strings.InstantPage_FontNewYork, textFont: .custom(font: Font.with(size: 17.0, design: .serif, traits: []), height: nil, verticalOffset: nil), icon: forceIsSerif ? checkIcon : emptyIcon, action: { (controller, action) in
                        performAction.invoke(.updateFontIsSerif(true))
                        action(.default)
                    })),
                    .separator,
                    .action(ContextMenuActionItem(text: self.presentationData.strings.InstantPage_Search, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings/Search"), color: theme.contextMenu.primaryColor) }, action: { (controller, action) in
                        performAction.invoke(.updateSearchActive(true))
                        action(.default)
                    })),
                    .action(ContextMenuActionItem(text: self.presentationData.strings.InstantPage_OpenInBrowser(openInTitle).string, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Instant View/Settings/Browser"), color: theme.contextMenu.primaryColor) }, action: { [weak self] (controller, action) in
                        if let self {
                            self.context.sharedContext.applicationBindings.openUrl(openInUrl)
                        }
                        action(.default)
                    }))
                ]
                
                let contextController = ContextController(presentationData: self.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))))
                self.controller?.present(contextController, in: .window(.root))
            })
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result == self.componentHost.view, let content = self.content.last {
                return content.hitTest(self.view.convert(point, to: content), with: event)
            }
            return result
        }
        
        private var scrollingPanelOffsetFraction: CGFloat = 0.0
        private var scrollingPanelOffsetToTopEdge: CGFloat = 0.0
        private var scrollingPanelOffsetToBottomEdge: CGFloat = .greatestFiniteMagnitude

        private var navigationBarHeight: CGFloat?
        private var toolbarHeight: CGFloat?
        func onContentScrollingUpdate(_ update: ContentScrollingUpdate) {
            var offsetDelta: CGFloat?
            offsetDelta = (update.absoluteOffsetToTopEdge ?? 0.0) - self.scrollingPanelOffsetToTopEdge
            if update.isReset {
                offsetDelta = 0.0
            }
            
            self.scrollingPanelOffsetToTopEdge = update.absoluteOffsetToTopEdge ?? 0.0
            self.scrollingPanelOffsetToBottomEdge = update.absoluteOffsetToBottomEdge ?? .greatestFiniteMagnitude
            
            if let topPanelHeight = self.navigationBarHeight, let bottomPanelHeight = self.toolbarHeight {
                var scrollingPanelOffsetFraction = self.scrollingPanelOffsetFraction
                
                if topPanelHeight > 0.0, let offsetDelta = offsetDelta {
                    let fractionDelta = -offsetDelta / topPanelHeight
                    scrollingPanelOffsetFraction = max(0.0, min(1.0, self.scrollingPanelOffsetFraction - fractionDelta))
                }
                
                if bottomPanelHeight > 0.0 && self.scrollingPanelOffsetToBottomEdge < bottomPanelHeight {
                    scrollingPanelOffsetFraction = min(scrollingPanelOffsetFraction, self.scrollingPanelOffsetToBottomEdge / bottomPanelHeight)
                } else if topPanelHeight > 0.0 && self.scrollingPanelOffsetToTopEdge < topPanelHeight {
                    scrollingPanelOffsetFraction = min(scrollingPanelOffsetFraction, self.scrollingPanelOffsetToTopEdge / topPanelHeight)
                }
                
                var transition = update.transition
                if !update.isInteracting {
                    if scrollingPanelOffsetFraction < 0.5 {
                        scrollingPanelOffsetFraction = 0.0
                    } else {
                        scrollingPanelOffsetFraction = 1.0
                    }
                    if case .none = transition.animation {
                    } else {
                        transition = transition.withAnimation(.curve(duration: 0.25, curve: .easeInOut))
                    }
                }
                
                if scrollingPanelOffsetFraction != self.scrollingPanelOffsetFraction {
                    self.scrollingPanelOffsetFraction = scrollingPanelOffsetFraction
                    self.requestLayout(transition: transition)
                }
            }
        }
        
        func navigateTo(_ item: BrowserContentState.HistoryItem) {
            if let _ = item.webItem {
                if let last = self.content.last {
                    last.navigateTo(historyItem: item)
                }
            } else if let uuid = item.uuid {
                var newContent = self.content
                while newContent.last?.uuid != uuid {
                    newContent.removeLast()
                }
                self.content = newContent
                self.requestLayout(transition: .spring(duration: 0.4))
            }
        }
        
        func performHoldAction(view: UIView, gesture: ContextGesture?, action: BrowserScreen.Action) {
            guard let controller = self.controller, let contentState = self.contentState else {
                return
            }
            
            let source: ContextContentSource = .reference(BrowserReferenceContentSource(controller: controller, sourceView: view))
            var items: [ContextMenuItem] = []
            switch action {
            case .navigateBack:
                for item in contentState.backList {
                    items.append(.action(ContextMenuActionItem(text: item.title, textLayout: .secondLineWithValue(item.url), icon: { _ in return nil }, action: { [weak self] (_, action) in
                        self?.navigateTo(item)
                        action(.default)
                    })))
                }
            case .navigateForward:
                for item in contentState.forwardList {
                    items.append(.action(ContextMenuActionItem(text: item.title, textLayout: .secondLineWithValue(item.url), icon: { _ in return nil }, action: { [weak self] (_, action) in
                        self?.navigateTo(item)
                        action(.default)
                    })))
                }
            default:
                return
            }
            
            let contextController = ContextController(presentationData: self.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))))
            self.controller?.present(contextController, in: .window(.root))
        }
        
        func requestLayout(transition: ComponentTransition) {
            if let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, navigationBarHeight: navigationBarHeight, transition: transition)
            }
        }
        
        func containerLayoutUpdated(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ComponentTransition) {
            self.validLayout = (layout, navigationBarHeight)
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                navigationHeight: navigationBarHeight,
                safeInsets: UIEdgeInsets(
                    top: layout.intrinsicInsets.top + layout.safeInsets.top,
                    left: layout.safeInsets.left,
                    bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom,
                    right: layout.safeInsets.right
                ),
                additionalInsets: layout.additionalInsets,
                inputHeight: layout.inputHeight ?? 0.0,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                orientation: nil,
                isVisible: true,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
                controller: { [weak self] in
                    return self?.controller
                }
            )

            let componentSize = self.componentHost.update(
                transition: transition,
                component: AnyComponent(
                    BrowserScreenComponent(
                        context: self.context,
                        contentState: self.contentState,
                        presentationState: self.presentationState,
                        performAction: self.performAction,
                        performHoldAction: { [weak self] view, gesture, action in
                            if let self {
                                self.performHoldAction(view: view, gesture: gesture, action: action)
                            }
                        },
                        panelCollapseFraction: self.scrollingPanelOffsetFraction
                    )
                ),
                environment: {
                    environment
                },
                forceUpdate: false,
                containerSize: layout.size
            )
            if let componentView = self.componentHost.view {
                if componentView.superview == nil {
                    self.view.addSubview(componentView)
                    componentView.clipsToBounds = true
                }
                transition.setFrame(view: componentView, frame: CGRect(origin: .zero, size: componentSize))
            }
            transition.setFrame(view: self.contentContainerView, frame: CGRect(origin: .zero, size: layout.size))
                
            var items: [AnyComponentWithIdentity<Empty>] = []
            for content in self.content {
                items.append(
                    AnyComponentWithIdentity(id: content.uuid, component: AnyComponent(
                        BrowserContentComponent(
                            content: content,
                            insets: UIEdgeInsets(
                                top: environment.statusBarHeight,
                                left: layout.safeInsets.left,
                                bottom: layout.intrinsicInsets.bottom,
                                right: layout.safeInsets.right
                            ),
                            navigationBarHeight: navigationBarHeight,
                            scrollingPanelOffsetFraction: self.scrollingPanelOffsetFraction
                        )
                    ))
                )
            }
            
            let _ = self.contentNavigationContainer.update(
                transition: transition,
                component: AnyComponent(
                    NavigationStackComponent(
                        items: items,
                        requestPop: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.popContent(transition: .spring(duration: 0.4))
                        }
                    )
                ),
                environment: {},
                containerSize: layout.size
            )
            let navigationFrame = CGRect(origin: .zero, size: layout.size)
            if let view = self.contentNavigationContainer.view {
                if view.superview == nil {
                    self.contentContainerView.addSubview(view)
                }
                transition.setFrame(view: view, frame: navigationFrame)
            }
            
            self.navigationBarHeight = environment.navigationHeight
            self.toolbarHeight = 49.0
        }
    }
    
    public enum Subject {
        case webPage(url: String)
        case instantPage(webPage: TelegramMediaWebpage, anchor: String?, sourceLocation: InstantPageSourceLocation)
    }
    
    private let context: AccountContext
    private let subject: Subject
    
    public init(context: AccountContext, subject: Subject) {
        self.context = context
        self.subject = subject
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .modal
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .allButUpsideDown)
        
        self.scrollToTop = { [weak self] in
            self?.node.content.last?.scrollToTop()
        }
    }
    
    required public init(coder: NSCoder) {
        preconditionFailure()
    }
    
    private var node: Node {
        return self.displayNode as! Node
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.node.containerLayoutUpdated(layout: layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.height, transition: ComponentTransition(transition))
    }
    
    public var isMinimized = false
    public var isMinimizable = true
    
    public var minimizedIcon: UIImage? {
        if let contentState = self.node.contentState {
            switch contentState.contentType {
            case .webPage:
                return contentState.favicon
            case .instantPage:
                return UIImage(bundleImageName: "Chat/Message/AttachedContentInstantIcon")?.withRenderingMode(.alwaysTemplate)
            }
        }
        return nil
    }
    
    public var minimizedProgress: Float? {
        if let contentState = self.node.contentState {
            return Float(contentState.readingProgress)
        }
        return nil
    }
}

private final class BrowserReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView

    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class BrowserContentComponent: Component {
    let content: BrowserContent
    let insets: UIEdgeInsets
    let navigationBarHeight: CGFloat
    let scrollingPanelOffsetFraction: CGFloat
    
    init(
        content: BrowserContent,
        insets: UIEdgeInsets,
        navigationBarHeight: CGFloat,
        scrollingPanelOffsetFraction: CGFloat
    ) {
        self.content = content
        self.insets = insets
        self.navigationBarHeight = navigationBarHeight
        self.scrollingPanelOffsetFraction = scrollingPanelOffsetFraction
    }
    
    static func ==(lhs: BrowserContentComponent, rhs: BrowserContentComponent) -> Bool {
        if lhs.content.uuid != rhs.content.uuid {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.navigationBarHeight != rhs.navigationBarHeight {
            return false
        }
        if lhs.scrollingPanelOffsetFraction != rhs.scrollingPanelOffsetFraction {
            return false
        }
        return true
    }

    final class View: UIView {
        init() {
            super.init(frame: CGRect())
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: BrowserContentComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            if component.content.superview !== self {
                self.addSubview(component.content)
            }
            
            let collapsedHeight: CGFloat = 24.0
            let topInset: CGFloat = component.insets.top + component.navigationBarHeight * (1.0 - component.scrollingPanelOffsetFraction) + collapsedHeight * component.scrollingPanelOffsetFraction
            let bottomInset = 49.0 + component.insets.bottom
            component.content.updateLayout(size: availableSize, insets: UIEdgeInsets(top: topInset, left: component.insets.left, bottom: bottomInset, right: component.insets.right), transition: transition)
            transition.setFrame(view: component.content, frame: CGRect(origin: .zero, size: availableSize))
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
