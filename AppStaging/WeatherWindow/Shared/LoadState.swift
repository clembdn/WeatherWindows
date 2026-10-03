/// Where an asynchronous screen is: the view switches on it instead of guessing.
nonisolated enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(ServiceError)
}
