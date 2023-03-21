import Combine
import UIKit
import R2Shared
import R2Navigator

class EPUBViewController: ReaderViewController {
  private var translateSubject = PassthroughSubject<Locator, Never>()
  lazy var translatePublisher = translateSubject.eraseToAnyPublisher()

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
        translateSubject.send(selection.locator)
        navigator.clearSelection()
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
