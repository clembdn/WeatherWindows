//
//  LoadState.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(ServiceError)
}
