//
//  TasksActor.swift
//  TasksActor
//
//  Created by Nikita Kislyakov on 18.05.2023.
//

actor TasksActor<Key: Hashable & Sendable, Value: Sendable> {
    private var tasks: [Key: Task<Value, Error>] = [:]

    /// Подключиться к текущей задаче, если она есть. Если ее нет, то вернется `nil`
    func valueIfLaunched(byKey key: Key) async throws -> Value? {
        if let currentTask = tasks[key] {
            return try await withCancellation(of: currentTask)
        } else {
            return nil
        }
    }

    private(set) var results: [Key: Result<Value, Error>] = [:]

    /// Выполнить асинхронную задачу, если текущей задачи нет.
    /// Если текущая задача есть, то подключиться к ней и ожидать ее результата
    /// - Parameter launchClosure: Асинхронная задача
    /// - Returns: Значение, возвращаемое текущей или новой асинхронной задачей
    func launchIfNeeded(
        byKey key: Key,
        _ launchClosure: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        if let value = try await valueIfLaunched(byKey: key) {
            return value
        }
        return try await launch(byKey: key, launchClosure)
    }

    private func launch(
        byKey key: Key,
        _ launchClosure: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let task = Task<Value, Error> {
            do {
                let value = try await launchClosure()
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
