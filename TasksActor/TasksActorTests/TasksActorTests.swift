//
//  TasksActorTests.swift
//  TasksActorTests
//
//  Created by Nikita Kislyakov on 18.05.2023.
//

import XCTest
@testable import TasksActor

final class TasksActorTests: XCTestCase {
    func test_launchIfNeeded_simultaneously() async throws {
        // given
        let key = "SomeKey"
        let sut = TasksActor<String, Int>()

        // when
        let result = try await withThrowingTaskGroup(of: Int.self, returning: [Int].self) { taskGroup in
            taskGroup.addTask {
                try await sut.launchIfNeeded(byKey: key) {
                    try await Task.sleep(nanoseconds: NSEC_PER_SEC / 100)
                    return 0
                }
            }
            taskGroup.addTask {
                try await sut.launchIfNeeded(byKey: key) {
                    try await Task.sleep(nanoseconds: NSEC_PER_SEC / 100)
                    return 1
                }
            }

            var values: [Int] = []
            for try await value in taskGroup {
                values.append(value)
            }
            return values
        }

        // then
        XCTAssertEqual(Set(result).count, 1)
        let valueIfLaunched = try await sut.operationLaunched(byKey: key)
        XCTAssertNil(valueIfLaunched)
        let lastResult = await sut.results[key]
        XCTAssertNotNil(try lastResult?.get())
    }

    func test_launchIfNeeded_sequentially() async throws {
        // given
        let key = "SomeKey"
        let sut = TasksActor<String, Int>()

        // when
        let result = try await withThrowingTaskGroup(of: Int.self, returning: [Int].self) { taskGroup in
            taskGroup.addTask {
                try await sut.launchIfNeeded(byKey: key) {
                    return 0
                }
            }
            taskGroup.addTask {
                await Task.yield()
                try await Task.sleep(nanoseconds: NSEC_PER_SEC / 100)
                return try await sut.launchIfNeeded(byKey: key) {
                    try await Task.sleep(nanoseconds: NSEC_PER_SEC / 100)
                    return 1
                }
            }

            var values: [Int] = []
            for try await value in taskGroup {
                values.append(value)
            }
            return values
        }

        // then
        XCTAssertEqual(result, [0, 1])
        let valueIfLaunched = try await sut.operationLaunched(byKey: key)
        XCTAssertNil(valueIfLaunched)
        let lastResult = await sut.results[key]
        XCTAssertEqual(try lastResult?.get(), 1)
    }

    func test_valueIfLaunched_simultaneously() async throws {
        // given
        let key = "SomeKey"
        let sut = TasksActor<String, Int>()

        // when
        let result = try await withThrowingTaskGroup(of: Int.self, returning: [Int].self) { taskGroup in
            taskGroup.addTask {
                try await sut.launchIfNeeded(byKey: key) {
                    try await Task.sleep(nanoseconds: NSEC_PER_SEC / 10)
                    return 1
                }
            }
            taskGroup.addTask {
                await Task.yield()
                try await Task.sleep(nanoseconds: NSEC_PER_SEC / 100)
                return try await sut.operationLaunched(byKey: key) ?? 0
            }

            var values: [Int] = []
            for try await value in taskGroup {
                values.append(value)
            }
            return values
        }

        XCTAssertEqual(result, [1, 1])
        let valueIfLaunched = try await sut.operationLaunched(byKey: key)
        XCTAssertNil(valueIfLaunched)
        let lastResult = await sut.results[key]
        XCTAssertEqual(try lastResult?.get(), 1)
    }

    func test_valueIfLaunched_noCurrentTask() async throws {
        // given
        let key = "SomeKey"
        let sut = TasksActor<String, Int>()

        // when
        let result = try await sut.operationLaunched(byKey: key)

        // then
        XCTAssertNil(result)
        let lastResult = await sut.results[key]
        XCTAssertNil(lastResult)
    }
}
