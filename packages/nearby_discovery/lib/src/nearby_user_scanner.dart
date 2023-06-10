import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import './nearby_scanner.dart';

class NearbyUserScanner extends NearbyScanner<String> {
  NearbyUserScanner({
    required FlutterReactiveBle ble,
  }) : _ble = ble;

  final FlutterReactiveBle _ble;
  final Set<String> _discoveredDevices = {};
  final Map<String, StreamSubscription<ConnectionStateUpdate>>
      _deviceConnections = {};
  final StreamController<String> _nearbyUserStreamController =
      StreamController();

  StreamSubscription? _deviceScanSubscription;

  @override
  Stream<String> get onNewScanningResult => _nearbyUserStreamController.stream;

  @override
  Future<void> init() async {
    await _waitForReady();
  }

  @override
  Future<void> dispose() async {
    await stopScanning();
    await _nearbyUserStreamController.close();
  }

  @override
  Future<void> startScanning() async {
    _discoveredDevices.clear();
    await _deviceScanSubscription?.cancel();
    _deviceScanSubscription = _ble.scanForDevices(
        withServices: [_serviceUuid]).listen(_handleDiscoveredDevice);
  }

  @override
  Future<void> stopScanning() async {
    await _deviceScanSubscription?.cancel();
    _deviceScanSubscription = null;
    _deviceConnections.forEach((_, connectionSubscription) {
      connectionSubscription.cancel();
    });
  }

  Future<void> _waitForReady() async {
    await _ble.statusStream.firstWhere((status) => status == BleStatus.ready);
  }

  void _handleDiscoveredDevice(DiscoveredDevice device) {
    if (_discoveredDevices.contains(device.id)) {
      return;
    }

    _readCharacteristicFromDevice(device.id);
  }

  void _readCharacteristicFromDevice(String deviceId) {
    _connectDevice(deviceId, onConnected: (deviceId) {
      _readCharacteristic(deviceId)
          .then(_nearbyUserStreamController.add)
          .whenComplete(() => _deviceConnections[deviceId]?.cancel());
    });
  }

  StreamSubscription<ConnectionStateUpdate> _connectDevice(String deviceId,
          {required void Function(String deviceId) onConnected}) =>
      _deviceConnections[deviceId] =
          _ble.connectToDevice(id: deviceId).listen((stateUpdate) {
        if (stateUpdate.connectionState == DeviceConnectionState.connected) {
          onConnected(deviceId);
        }
      });

  Future<String> _readCharacteristic(String deviceId) {
    final characteristic = QualifiedCharacteristic(
        serviceId: _serviceUuid,
        characteristicId: _characteristicUuid,
        deviceId: deviceId);
    return _ble.readCharacteristic(characteristic).then(_parse);
  }
}

final Uuid _serviceUuid = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
final Uuid _characteristicUuid =
    Uuid.parse("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");

String _parse(List<int> rawData) => String.fromCharCodes(rawData);
