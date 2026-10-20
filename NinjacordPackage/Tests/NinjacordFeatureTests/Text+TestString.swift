//
//  Text+TestString.swift
//  NinjacordFeatureTests
//

import SwiftUI

extension Text {
    /// テストで文言を比べるための文字列。ローカライズのキーに、差し込んだ値を埋めたもの（訳さない）。
    /// Text には文言を取り出す API が無く、値を差し込んだ Text は == でも比べられないので、Mirror で中身を読む。
    /// SwiftUI の内部の形が変わって読めなくなったときは nil を返す（テストが失敗して気づける）
    var testString: String? {
        guard let storage = Mirror(reflecting: self).descendant("storage") else {
            return nil
        }
        let storageMirror = Mirror(reflecting: storage)
        if let verbatim = storageMirror.descendant("verbatim") as? String {
            return verbatim
        }
        guard let textStorage = storageMirror.children.first?.value,
              let key = Mirror(reflecting: textStorage).descendant("key"),
              let format = Mirror(reflecting: key).descendant("key") as? String,
              let arguments = Mirror(reflecting: key).descendant("arguments") as? [Any] else {
            return nil
        }
        let values = arguments.compactMap { Mirror(reflecting: $0).descendant("storage", "value", ".0") as? CVarArg }
        guard values.count == arguments.count else {
            return nil
        }
        return String(format: format, arguments: values)
    }
}
