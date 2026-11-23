//
//  Result+TestValues.swift
//  NinjacordFeatureTests
//

/// テストで成否と中身を `#expect` で比べるための読み出し
extension Result {
    var successValue: Success? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }

    var isSuccess: Bool {
        successValue != nil
    }

    var failureValue: Failure? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
