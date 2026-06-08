import SwiftUI

public struct ModuleAButton: View {
  public let title: String

  public init(title: String = "ModuleA Button") {
    self.title = title
  }

  public var body: some View {
    Button(title) {}
      .buttonStyle(.borderedProminent)
  }
}

public struct ModuleALabel: View {
  public let text: String

  public init(text: String = "ModuleA Label") {
    self.text = text
  }

  public var body: some View {
    Text(text)
      .font(.title)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(.thinMaterial, in: Capsule())
  }
}

#Preview("ModuleA Button") {
  ModuleAButton()
}

#Preview("ModuleA Label Light") {
  ModuleALabel()
    .preferredColorScheme(.light)
}

#Preview("ModuleA Label Dark") {
  ModuleALabel()
    .preferredColorScheme(.dark)
}
