import Combine
import UIKit
import R2Shared
import R2Navigator
import SwiftUI

enum EPUBViewEvent {
    case translate(Locator)
    case showHighlight(Int)
    case deleteHighlight(Int)
}

class EPUBViewController: ReaderViewController {
  private var epubViewSubject = PassthroughSubject<EPUBViewEvent, Never>()
  lazy var epubViewPublisher = epubViewSubject.eraseToAnyPublisher()

    init(
      publication: Publication,
      locator: Locator?,
      bookId: String,
      resourcesServer: ResourcesServer
    ) {
      var navigatorEditingActions = EditingAction.defaultActions
      navigatorEditingActions.removeAll()
      navigatorEditingActions.append(EditingAction(title: "Translate", action: #selector(translateSelection)))
      var navigatorConfig = EPUBNavigatorViewController.Configuration()
      navigatorConfig.editingActions = navigatorEditingActions

      let navigator = EPUBNavigatorViewController(
        publication: publication,
        initialLocation: locator,
        resourcesServer: resourcesServer,
        config: navigatorConfig
      )

      super.init(
        navigator: navigator,
        publication: publication,
        bookId: bookId
      )

      navigator.delegate = self

      addHighlightDecorationsObserverOnce()
    }

    var epubNavigator: EPUBNavigatorViewController {
      return navigator as! EPUBNavigatorViewController
    }

    override func viewDidLoad() {
      super.viewDidLoad()

      /// Set initial UI appearance.
      if let appearance = publication.userProperties.getProperty(reference: ReadiumCSSReference.appearance.rawValue) {
        setUIColor(for: appearance)
      }
    }

    internal func setUIColor(for appearance: UserProperty) {
      let colors = AssociatedColors.getColors(for: appearance)

      navigator.view.backgroundColor = colors.mainColor
      view.backgroundColor = colors.mainColor
      //
      navigationController?.navigationBar.barTintColor = colors.mainColor
      navigationController?.navigationBar.tintColor = colors.textColor

      navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: colors.textColor]
    }

    override var currentBookmark: Bookmark? {
      guard let locator = navigator.currentLocation else {
        return nil
      }

      return Bookmark(bookId: bookId, locator: locator)
    }

    @objc func translateSelection() {
      if let navigator = navigator as? SelectableNavigator, let selection = navigator.currentSelection {
        epubViewSubject.send(.translate(selection.locator))
        navigator.clearSelection()
      }
    }

    private var highlightContextMenu: UIHostingController<HighlightContextMenu>?

    func updateHighlightsFromList(highlights: [Highlight]) {
      if let decorator = navigator as? DecorableNavigator {
        let decorations = highlights.map {
          Decoration(id: $0.id, locator: $0.locator, style: .highlight(tint: UIColor.yellow, isActive: false))
        }
        decorator.apply(decorations: decorations, in: "highlights")
      }
    }

    private func addHighlightDecorationsObserverOnce() {
      if let decorator = navigator as? DecorableNavigator {
        decorator.observeDecorationInteractions(inGroup: "highlights") { [weak self] event in
          self?.activateDecoration(event)
        }
      }
    }

    private func activateDecoration(_ event: OnDecorationActivatedEvent) {
      let id: Int? = Int(event.decoration.id)
      if (id == nil) {
        return
      }

      if highlightContextMenu != nil {
        highlightContextMenu?.removeFromParent()
      }

      let menuView = HighlightContextMenu(systemFontSize: 20)

      menuView.selectShowPublisher.sink { [weak self] _ in
        self?.epubViewSubject.send(.showHighlight(id!))
        self?.highlightContextMenu?.dismiss(animated: true, completion: nil)
      }
      .store(in: &subscriptions)

      menuView.selectDeletePublisher.sink { [weak self] _ in
        self?.epubViewSubject.send(.deleteHighlight(id!))
        self?.highlightContextMenu?.dismiss(animated: true, completion: nil)
      }
      .store(in: &subscriptions)

      highlightContextMenu = UIHostingController(rootView: menuView)
      highlightContextMenu!.preferredContentSize = menuView.preferredSize
      highlightContextMenu!.modalPresentationStyle = .popover

      if let popoverController = highlightContextMenu?.popoverPresentationController {
        popoverController.permittedArrowDirections = [.up, .down]
        popoverController.sourceRect = event.rect ?? .zero
        popoverController.sourceView = view
        popoverController.delegate = self
        present(highlightContextMenu!, animated: true, completion: nil)
      }
    }
}

extension EPUBViewController: EPUBNavigatorDelegate {}

extension EPUBViewController: UIGestureRecognizerDelegate {

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }

}

extension EPUBViewController: UIPopoverPresentationControllerDelegate {
  // Prevent the popOver to be presented fullscreen on iPhones.
  func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle
  {
    return .none
  }
}
