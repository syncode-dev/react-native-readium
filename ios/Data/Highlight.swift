import Combine
import Foundation
import R2Shared

struct Highlight {
  let id: String
  var locator: Locator

  init(id: String, locator: Locator) {
    self.id = id
    self.locator = locator
  }
}
