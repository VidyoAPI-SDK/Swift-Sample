//
//  EventCounter.swift
//  BroadcastExtension
//
//  Created by Marta Korol on 25.07.2021.
//

import Foundation

/*
 An object to calculate average intervals between events, e.g. FPS
 1. Initialize with a time interval to count events and report callback. Default wrapCount = 60
 2. Call tick() when an event happens
 3. Once tick() was called wrapCount times, accumulatedCounter is updated and average FPS is reported through callback
 */

class EventIntervalCounter {
    private let wrapCount: Int
    private let reportCallback: (Double)->Void
    
    private var prevDate: Date?
    private var runningCounter = AverageCounter()    
    private var accumulatedCounter = AverageCounter()
    
    var accumulatedAverageInterval: Double {
        return accumulatedCounter.average
    }
    
    // MARK: - Initialisation
    init(reportCallback: @escaping (Double)->Void = {_ in}, wrapCount: Int = 60) {
        self.reportCallback = reportCallback
        self.wrapCount = wrapCount
    }
    
    // MARK: - Methods
    func start() {
        prevDate = nil
        accumulatedCounter = AverageCounter()
        runningCounter = AverageCounter()
    }
    
    func stop() {
        accumulatedCounter.insert(value: runningCounter.average)
    }
    
    func tick() {
        defer {
            prevDate = Date()
            if runningCounter.i == wrapCount {
                reportCallback(runningCounter.average)
                prevDate = nil
                accumulatedCounter.insert(value: runningCounter.average)
                runningCounter = AverageCounter()
            }
        }
        guard let prev = prevDate else { return }
        runningCounter.insert(value: Date().timeIntervalSince(prev))
    }
}

// MARK: - AverageCounter
private struct AverageCounter {
    private(set) var i: UInt64 = 0
    private(set) var average: Double = 0.0
    
    mutating func insert(value: Double) {
        guard i < UInt64.max else { return }
        average = ((average * Double(i)) + value) / Double(i + 1)
        i += 1
    }
}
