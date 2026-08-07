swiftui_interface = Dir['/Applications/Xcode.app/Contents/Developer/Platforms/**/SwiftUI.framework/**/*.swiftinterface']
uikit_interface = Dir['/Applications/Xcode.app/Contents/Developer/Platforms/**/UIKit.framework/**/*.swiftinterface']
developer_tools_interface = Dir['/Applications/Xcode.app/Contents/Developer/Platforms/**/DeveloperToolsSupport.framework/**/*.swiftinterface']

for file_path in developer_tools_interface
  if !File.read(file_path).include?("DefaultPreviewSource")
    File.open(file_path, 'a') do |file|
      file.puts("@available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
      public struct DefaultPreviewSource<A> {
        public var structure: DefaultPreviewSource<A>.Structure

        public enum Structure {
          case singlePreview(makeBody: @_Concurrency.MainActor () -> A)
        }
      }")
    end
  end
end

for file_path in swiftui_interface
  if !File.read(file_path).include?("ViewPreviewSource")
    File.open(file_path, 'a') do |file|
      file.puts("@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
      public struct ViewPreviewSource {
        public var makeView: @_Concurrency.MainActor () -> any SwiftUI.View
      }
      @available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
      public struct ViewPreviewBody {
        public var body: SwiftUI.View { get }
      }
      ")
    end
  end

  if !File.read(file_path).include?("PreviewModifierViewModifier")
    File.open(file_path, 'a') do |file|
      file.puts("@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
      public struct PreviewModifierViewModifier<A> where A : PreviewModifier {
        public func body(content: SwiftUI._ViewModifier_Content<PreviewModifierViewModifier<A>>) -> some View
        public init(modifier: A, context: A.Context)
      }
      @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
      extension PreviewModifierViewModifier : SwiftUI.ViewModifier where A : SwiftUI.PreviewModifier {
      }")
    end
  end
end

for file_path in uikit_interface
  if !file_path.include?("Watch") && !File.read(file_path).include?("UIViewPreviewSource")
    File.open(file_path, 'a') do |file|
      file.puts("@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
      public struct UIViewPreviewSource {
        public var makeView: @_Concurrency.MainActor () -> UIKit.UIView
      }
      
      @available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
      public struct UIViewControllerPreviewSource {
        public var makeViewController: @_Concurrency.MainActor () -> UIKit.UIViewController
      }")
    end
  end
end