abstract class NearbyScanner<T> {
  Stream<T> get onNewScanningResult;

  Future<void> init();
  Future<void> dispose();
  Future<void> startScanning();
  Future<void> stopScanning();
}
