//
//  SpySessionAdaptor.swift
//  
//
//  Created by Ryotaro Seki on 2023/06/01.
//

import APIKit
import Foundation

private var myDataTaskResponseBufferKey = 0
private var myTaskAssociatedObjectCompletionHandlerKey = 0

private let spySessionAdaptor = SpySessionAdapter(configuration: .default)

let spySession = Session(adapter: spySessionAdaptor)

open class SpySessionAdapter: NSObject, SessionAdapter, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    open var urlSession: URLSession!

    public init(configuration: URLSessionConfiguration) {
        super.init()
        self.urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    /// Creates `URLSessionDataTask` instance using `dataTaskWithRequest(_:completionHandler:)`.
    open func createTask(with URLRequest: URLRequest, handler: @escaping (Data?, URLResponse?, Error?) -> Void) -> SessionTask {
        let task = urlSession.dataTask(with: URLRequest)

        setBuffer(NSMutableData(), forTask: task)

        let spyHander: (Data?, URLResponse?, Error?) -> Void = { data, response, error in
            print("data: \(data?.hexString() ?? "nil")")
            if let response = response as? HTTPURLResponse {
                print("url: \(response.url?.absoluteString ?? "nil")")
                print("code: \(response.statusCode)")
                print("header: \(response.allHeaderFields)")
            }
            if let error {
                print("error: \(error)")
            }
            handler(data, response, error)
        }
        setHandler(spyHander, forTask: task)

        return task
    }

    /// Aggregates `URLSessionTask` instances in `URLSession` using `getTasksWithCompletionHandler(_:)`.
    open func getTasks(with handler: @escaping ([SessionTask]) -> Void) {
        urlSession.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            let allTasks: [URLSessionTask] = dataTasks + uploadTasks + downloadTasks
            handler(allTasks)
        }
    }

    private func setBuffer(_ buffer: NSMutableData, forTask task: URLSessionTask) {
        objc_setAssociatedObject(task, &myDataTaskResponseBufferKey, buffer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func buffer(for task: URLSessionTask) -> NSMutableData? {
        return objc_getAssociatedObject(task, &myDataTaskResponseBufferKey) as? NSMutableData
    }

    private func setHandler(_ handler: @escaping (Data?, URLResponse?, Error?) -> Void, forTask task: URLSessionTask) {
        objc_setAssociatedObject(task, &myTaskAssociatedObjectCompletionHandlerKey, handler as Any, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func handler(for task: URLSessionTask) -> ((Data?, URLResponse?, Error?) -> Void)? {
        return objc_getAssociatedObject(task, &myTaskAssociatedObjectCompletionHandlerKey) as? (Data?, URLResponse?, Error?) -> Void
    }

    // MARK: URLSessionTaskDelegate
    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        handler(for: task)?(buffer(for: task) as Data?, task.response, error)
    }

    // MARK: URLSessionDataDelegate
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer(for: dataTask)?.append(data)
    }
}

extension Data {
    func hexString() -> String {
        self.map { String(format: "%02hhX", $0) }.joined(separator: " ")
    }
}
