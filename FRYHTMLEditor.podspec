#
# Be sure to run `pod lib lint FRYHTMLEditor.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'FRYHTMLEditor'
  s.version          = '0.1.3'
  s.summary          = 'A short description of FRYHTMLEditor.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
The basic HTML editor for iOS. Component is based on the WKWebView.
Frankly speaking it's the rewritten to swift and simplified version of ZSSRichTextEditor. The functionality is currently limited to bold, italic, underline, both ordered and unordered lists and links.
                       DESC

  s.homepage         = 'https://github.com/svyatoslav-zubrin/FRYHTMLEditor'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'svyatoslav-zubrin' => 'szubrin79@gmail.com' }
  s.source           = { :git => 'https://github.com/svyatoslav-zubrin/FRYHTMLEditor.git', :tag => s.version.to_s }

  s.ios.deployment_target = '14.0'
  s.swift_version = '5.5'

  s.source_files = 'Sources/FRYHTMLEditor/Classes/**/*'
  s.resources = ['Sources/FRYHTMLEditor/Resources/*']
end
