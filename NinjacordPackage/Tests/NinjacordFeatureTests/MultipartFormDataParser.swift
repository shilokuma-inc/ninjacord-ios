//
//  MultipartFormDataParser.swift
//  NinjacordFeatureTests
//

import Foundation

/// Discord に送る multipart/form-data の本文（payload_json と files[0] の 2 パート）を分ける。
/// payload_json の JSON はキーの並びが送るたびに変わりうるので、決まった部分（境界・ヘッダー）と中身を分けて確かめる
enum MultipartFormDataParser {
    struct Parts {
        let payloadJSON: Data
        let file: Data
    }

    /// 本文が Alamofire の MultipartFormData と同じ書式なら、2 つのパートの中身を返す。書式が違えば nil
    static func parse(_ body: Data, boundary: String, fileName: String, mimeType: String) -> Parts? {
        let head = Data(
            ("--\(boundary)\r\n"
                + "Content-Disposition: form-data; name=\"payload_json\"\r\n"
                + "Content-Type: application/json\r\n\r\n").utf8
        )
        let middle = Data(
            ("\r\n--\(boundary)\r\n"
                + "Content-Disposition: form-data; name=\"files[0]\"; filename=\"\(fileName)\"\r\n"
                + "Content-Type: \(mimeType)\r\n\r\n").utf8
        )
        let tail = Data("\r\n--\(boundary)--\r\n".utf8)

        guard body.starts(with: head),
              body.count >= head.count + middle.count + tail.count,
              body.suffix(tail.count) == tail,
              let middleRange = body.range(of: middle, in: head.count..<(body.count - tail.count)) else {
            return nil
        }
        return Parts(
            payloadJSON: body.subdata(in: head.count..<middleRange.lowerBound),
            file: body.subdata(in: middleRange.upperBound..<(body.count - tail.count))
        )
    }
}
