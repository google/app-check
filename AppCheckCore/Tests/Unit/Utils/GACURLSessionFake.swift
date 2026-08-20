import Foundation
@testable import AppCheckCore

class GACURLSessionFake {
    var resultResponse: GACURLSessionDataResponse?
    var resultError: Error?
    var lastRequest: URLRequest?
    var requestValidationBlock: ((URLRequest) -> Bool)?
    var isInvoked: Bool = false
    
    let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        session = URLSession(configuration: configuration)
        
        URLProtocolMock.requestHandler = { [weak self] request in
            guard let self = self else {
                throw NSError(domain: "GACURLSessionFake", code: -1, userInfo: nil)
            }
            self.isInvoked = true
            self.lastRequest = request
            
            if let validationBlock = self.requestValidationBlock {
                _ = validationBlock(request)
            }
            
            if let resultError = self.resultError {
                throw resultError
            }
            
            if let resultResponse = self.resultResponse {
                return (resultResponse.httpResponse, resultResponse.httpBody)
            }
            
            throw NSError(domain: "GACURLSessionFake", code: -1, userInfo: nil)
        }
    }
    
    static func httpResponse(withCode statusCode: Int) -> HTTPURLResponse {
        return HTTPURLResponse(url: URL(string: "https://url.com")!,
                               statusCode: statusCode,
                               httpVersion: "HTTP/1.1",
                               headerFields: nil)!
    }
}

class URLProtocolMock: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (URLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canInit(with task: URLSessionTask) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        if let handler = URLProtocolMock.requestHandler {
            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                if let data = data {
                    client?.urlProtocol(self, didLoad: data)
                }
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}
