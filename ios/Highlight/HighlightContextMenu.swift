import Combine
import SwiftUI

struct HighlightContextMenu: View {
  let systemFontSize: CGFloat

  private let showSubject = PassthroughSubject<Void, Never>()
  var selectShowPublisher: AnyPublisher<Void, Never> {
    showSubject.eraseToAnyPublisher()
  }

  private let deleteSubject = PassthroughSubject<Void, Never>()
  var selectDeletePublisher: AnyPublisher<Void, Never> {
    deleteSubject.eraseToAnyPublisher()
  }

  var body: some View {
    HStack {
      Button(action: {
        self.showSubject.send()
      }) {
        Text("Show")
          .fixedSize(horizontal: true, vertical: false)
          .frame(maxWidth: .infinity)
      }
      Button(action: {
        self.deleteSubject.send()
      }) {
        Text("Delete")
          .fixedSize(horizontal: true, vertical: false)
          .frame(maxWidth: .infinity)
      }
    }
  }

  var preferredSize: CGSize {
    let font = UIFont.systemFont(ofSize: systemFontSize)
    let fontAttributes = [NSAttributedString.Key.font: font]
    let size = ("Delete" as NSString).size(withAttributes: fontAttributes)
    return CGSize(width: size.width * 1.5 * CGFloat(2), height: size.height * 1.6)
  }
}
