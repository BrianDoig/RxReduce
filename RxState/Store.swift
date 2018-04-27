//
//  Store.swift
//  WarpFactorIOS
//
//  Created by Thibault Wittemberg on 18-04-15.
//  Copyright © 2018 WarpFactor. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa


/// A Reducer mutates an input state into an output state according to an action
public typealias Reducer<StateType: State> = (_ state: StateType?, _ action: Action) -> StateType

/// A Store holds the state, mutate the state through actions / reducers and exposes the state via a Driver
/// A Store is dedicated to a State Type
public protocol Store {
    associatedtype StateType: State

    /// The current State (UI compliant)
    var state: Driver<StateType> { get }

    /// Inits the Store with its reducers stack
    ///
    /// - Parameter reducers: the reducers to be executed by the dispatch function
    init(withReducers reducers: [Reducer<StateType>])

    /// Dispatch an action through the reducers to mutate the state
    ///
    /// - Parameter action: the actual action that will go through the reducers
    func dispatch (action: Action)
}

public final class DefaultStore<StateType: State>: Store {

    let disposeBag = DisposeBag()

    private let stateSubject = BehaviorRelay<StateType?>(value: nil)
    public lazy var state: Driver<StateType> = { [unowned self] in
        return self.stateSubject
            .asObservable()
            .filter { $0 != nil }
            .map { $0! }
            .asDriver(onErrorJustReturn: EmptyState())
        }()

    let reducers: [Reducer<StateType>]

    public init(withReducers reducers: [Reducer<StateType>]) {
        self.reducers = reducers
    }

    public func dispatch (action: Action) {
        action
            .toAsync(withState: self.stateSubject.value)
            .map { [unowned self] (action) -> StateType? in
                return self.reducers.reduce(self.stateSubject.value, { (currentState, reducer) -> StateType? in
                    return reducer(currentState, action)
                })
            }.subscribe(onNext: { [unowned self] (newState) in
                self.stateSubject.accept(newState)
            }).disposed(by: self.disposeBag)
    }
}