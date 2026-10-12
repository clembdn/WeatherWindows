// Where a screen that loads data is: the view switches on it instead of guessing.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(ServiceError)
}
