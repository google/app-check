import Foundation
#if canImport(DeviceCheck)
  import DeviceCheck

  @available(iOS 11.0, macOS 10.15, tvOS 11.0, watchOS 9.0, *)
  extension DCDevice: AppCheckCoreDeviceCheckTokenGenerator {}
#endif
