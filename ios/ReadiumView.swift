import Combine
import Foundation
import R2Shared
import R2Streamer
import UIKit
import R2Navigator


class ReadiumView : UIView, Loggable {
  var readerService: ReaderService = ReaderService()
  var readerViewController: ReaderViewController?
  var viewController: UIViewController? {
    let viewController = sequence(first: self, next: { $0.next }).first(where: { $0 is UIViewController })
    return viewController as? UIViewController
  }
  private var subscriptions = Set<AnyCancellable>()

  @objc var file: NSDictionary? = nil {
    didSet {
      let initialLocation = file?["initialLocation"] as? NSDictionary
      if let url = file?["url"] as? String {
        self.loadBook(url: url, location: initialLocation)
      }
    }
  }
  @objc var location: NSDictionary? = nil {
    didSet {
      self.updateLocation()
    }
  }
  @objc var settings: NSDictionary? = nil {
    didSet {
      self.updateUserSettings(settings)
    }
  }
  @objc var highlights: NSArray? = nil {
    didSet {
      self.updateHighlights(highlights)
    }
  }
  @objc var onLocationChange: RCTDirectEventBlock?
  @objc var onTableOfContents: RCTDirectEventBlock?
  @objc var onTranslate: RCTDirectEventBlock?
  @objc var onShowHighlight: RCTDirectEventBlock?
  @objc var onDeleteHighlight: RCTDirectEventBlock?

  func loadBook(
    url: String,
    location: NSDictionary?
  ) {
    guard let rootViewController = UIApplication.shared.delegate?.window??.rootViewController else { return }

    self.readerService.buildViewController(
      url: url,
      bookId: url,
      location: location,
      sender: rootViewController,
      completion: { vc in
        self.addViewControllerAsSubview(vc)
        self.location = location
      }
    )
  }

  func getLocator() -> Locator? {
    return ReaderService.locatorFromLocation(location, readerViewController?.publication)
  }

  func updateLocation() {
    guard let navigator = readerViewController?.navigator else {
      return;
    }
    guard let locator = self.getLocator() else {
      return;
    }

    let cur = navigator.currentLocation
    if (cur != nil && locator.hashValue == cur?.hashValue) {
      return;
    }

    navigator.go(
      to: locator,
      animated: true
    )
  }

  func updateUserSettings(_ settings: NSDictionary?) {

    if (readerViewController == nil) {
      // defer setting update as view isn't initialized yet
      return;
    }

    if let navigator = readerViewController!.navigator as? EPUBNavigatorViewController {
      let userProperties = navigator.userSettings.userProperties

      for property in userProperties.properties {
        let value = settings?[property.reference]

        if (value == nil) {
          continue
        }

        if let e = property as? Enumerable {
          e.index = value as! Int

          // synchronize background color
          if property.reference == ReadiumCSSReference.appearance.rawValue {
            if let vc = readerViewController as? EPUBViewController {
              vc.setUIColor(for: property)
            }
          }
        } else if let i = property as? Incrementable {
          i.value = value as! Float
        } else if let s = property as? Switchable {
          s.on = value as! Bool
        }
      }

      navigator.updateUserSettingStyle()
    }
  }

  func updateHighlights(_ highlights: NSArray?) {
    if (highlights == nil) {
      return
    }

    if (readerViewController == nil) {
      // defer highlights update as view isn't initialized yet
      return;
    }

    var list = [Highlight]()
    for element in highlights! {
      if let highlightDictionary = element as? NSDictionary {
        let id = highlightDictionary["id"] as? Int
        let locatorJson = highlightDictionary["locator"] as? NSDictionary
        if (id == nil || locatorJson == nil) {
          continue
        }
        if let locator = try? Locator(json: locatorJson!) {
          let highlight = Highlight(
            id: String(id!),
            locator: locator
          )
          list.append(highlight)
        }
      }
    }

    if let vc = readerViewController as? EPUBViewController {
      vc.updateHighlightsFromList(highlights: list)
    }
  }

  override func removeFromSuperview() {
    readerViewController?.willMove(toParent: nil)
    readerViewController?.view.removeFromSuperview()
    readerViewController?.removeFromParent()

    // cancel all current subscriptions
    for subscription in subscriptions {
      subscription.cancel()
    }
    subscriptions = Set<AnyCancellable>()

    readerViewController = nil
    super.removeFromSuperview()
  }

  private func addViewControllerAsSubview(_ vc: ReaderViewController) {
    vc.publisher.sink(
      receiveValue: { locator in
          self.onLocationChange?(locator.json)
      }
    )
    .store(in: &self.subscriptions)

    (vc as? EPUBViewController)?.epubViewPublisher.sink(
      receiveValue: { event in
        switch event {
        case .translate(let locator):
          self.onTranslate?(locator.json)
        case .showHighlight(let highlightId):
          self.onShowHighlight?(["id": highlightId])
        case .deleteHighlight(let highlightId):
          self.onDeleteHighlight?(["id": highlightId])
        }
      }
    )
    .store(in: &self.subscriptions)

    readerViewController = vc

    // if the controller was just instantiated then apply any existing settings
    if (settings != nil) {
      self.updateUserSettings(settings)
    }

    if (highlights != nil) {
      self.updateHighlights(highlights)
    }

    readerViewController!.view.frame = self.superview!.frame
    self.viewController!.addChild(readerViewController!)
    let rootView = self.readerViewController!.view!
    self.addSubview(rootView)
    self.viewController!.addChild(readerViewController!)
    self.readerViewController!.didMove(toParent: self.viewController!)

    // bind the reader's view to be constrained to its parent
    rootView.translatesAutoresizingMaskIntoConstraints = false
    rootView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
    rootView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
    rootView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
    rootView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true

    self.onTableOfContents?([
      "toc": vc.publication.tableOfContents.map({ link in
        return link.json
      })
    ])
  }
}
