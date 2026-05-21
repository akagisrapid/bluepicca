import Foundation

func dlog(_ item: Any) {
  #if DEBUG
    print(item)
  #endif
}
