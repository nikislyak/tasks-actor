//
//  TasksActor.swift
//  TasksActor
//
//  Created by Nikita Kislyakov on 18.05.2023.
//

actor TasksActor<Key: Hashable & Sendable, Value: Sendable> {
    private var tasks: [Key: Task<Value, Error>] = [:]

    /// Attach to an already running operation
    /// - Parameter key: Key of the operation
    /// - Returns: Value returned by corresponding running operation or `nil` if there is no operation by the key
    func operationLaunched(byKey key: Key) async throws -> Value? {
        if let currentTask = tasks[key] {
            return try await withCancellation(of: currentTask)
        } else {
            return nil
        }
    }

    /// Results of async work
    private(set) var results: [Key: Result<Value, Error>] = [:]

    /// Start a new async operation by key or attach to an already running operation
    /// - Parameter operation: Async operation
    /// - Returns: Value returned by corresponding running operation or a new operation
    func launchIfNeeded(
        byKey key: Key,
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        if let value = try await operationLaunched(byKey: key) {
            return value
        }
        return try await launch(byKey: key, operation)
    }

    private func launch(
        byKey key: Key,
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let task = Task<Value, Error> {
            do {
                let value = try await operation()
                results[key] = .success(value)
                tasks[key] = nil
                return value
            } catch {
                results[key] = .failure(error)
                tasks[key] = nil
                throw error
            }
        }
        tasks[key] = task
        return try await withCancellation(of: task)
    }

    nonisolated private func withCancellation(of task: Task<Value, Error>) async throws -> Value {
        try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
