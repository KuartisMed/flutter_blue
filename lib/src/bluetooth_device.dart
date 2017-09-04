// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue;

class BluetoothDevice {
  final DeviceIdentifier id;
  final String name;
  final BluetoothDeviceType type;

  BluetoothDevice(
      {@required this.id, this.name, this.type = BluetoothDeviceType.unknown});

  BluetoothDevice.fromProto(protos.BluetoothDevice p)
      : id = new DeviceIdentifier(p.remoteId),
        name = p.name,
        type = BluetoothDeviceType.values[p.type.value];

  /// Discovers services offered by the remote device as well as their characteristics and descriptors
  Future<List<BluetoothService>> discoverServices() async {
    await FlutterBlue.instance._channel
        .invokeMethod('discoverServices', id.toString());

    return await FlutterBlue.instance._servicesDiscoveredChannel
        .receiveBroadcastStream()
        .map((List<int> data) =>
            new protos.DiscoverServicesResult.fromBuffer(data))
        .where((p) => p.remoteId == id.toString())
        .map((p) => p.services)
        .map((s) => s.map((p) => new BluetoothService.fromProto(p)).toList())
        .first;
  }

  /// Returns a list of Bluetooth GATT services offered by the remote device
  /// This function requires that discoverServices has been completed for this device
  Future<List<BluetoothService>> get services {
    return FlutterBlue.instance._channel
        .invokeMethod('services', id.toString())
        .then((List<int> data) =>
            new protos.DiscoverServicesResult.fromBuffer(data).services)
        .then((i) => i.map((s) => new BluetoothService.fromProto(s)).toList());
  }

  /// Retrieves the value of a specified characteristic
  Future<List<int>> readCharacteristic(
      BluetoothCharacteristic characteristic) async {
    var request = protos.ReadCharacteristicRequest.create()
      ..remoteId = id.toString()
      ..characteristicUuid = characteristic.uuid.toString()
      ..serviceUuid = characteristic.serviceUuid.toString();

    await FlutterBlue.instance._channel
        .invokeMethod('readCharacteristic', request.writeToBuffer());

    return await FlutterBlue.instance._characteristicReadChannel
        .receiveBroadcastStream()
        .map((List<int> data) =>
            new protos.ReadCharacteristicResponse.fromBuffer(data))
        .where((p) =>
            (p.remoteId == request.remoteId) &&
            (p.characteristic.uuid == request.characteristicUuid) &&
            (p.characteristic.serviceUuid == request.serviceUuid))
        .map((p) => p.characteristic.value)
        .first
        .then((d) => characteristic.value = d);
  }

  /// Retrieves the value of a specified descriptor
  Future<List<int>> readDescriptor(BluetoothDescriptor descriptor) async {
    var request = protos.ReadDescriptorRequest.create()
      ..remoteId = id.toString()
      ..descriptorUuid = descriptor.uuid.toString()
      ..characteristicUuid = descriptor.characteristicUuid.toString()
      ..serviceUuid = descriptor.serviceUuid.toString();

    await FlutterBlue.instance._channel
        .invokeMethod('readDescriptor', request.writeToBuffer());

    return await FlutterBlue.instance._descriptorReadChannel
        .receiveBroadcastStream()
        .map((List<int> data) =>
            new protos.ReadDescriptorResponse.fromBuffer(data))
        .where((p) =>
            (p.request.remoteId == request.remoteId) &&
            (p.request.descriptorUuid == request.descriptorUuid) &&
            (p.request.characteristicUuid == request.characteristicUuid) &&
            (p.request.serviceUuid == request.serviceUuid))
        .map((d) => d.value)
        .first
        .then((d) => descriptor.value = d);
  }

  /// Writes the value of a characteristic.
  /// [CharacteristicWriteType.withoutResponse]: the write is not
  /// guaranteed and will return immediately with success.
  /// [CharacteristicWriteType.withResponse]: the method will return after the
  /// write operation has either passed or failed.
  Future<Null> writeCharacteristic(BluetoothCharacteristic characteristic, List<int> value,
      {CharacteristicWriteType type =
          CharacteristicWriteType.withoutResponse}) async {
    var request = protos.WriteCharacteristicRequest.create()
      ..remoteId = id.toString()
      ..characteristicUuid = characteristic.uuid.toString()
      ..serviceUuid = characteristic.serviceUuid.toString()
      ..writeType = protos.WriteCharacteristicRequest_WriteType.valueOf(type.index)
      ..value = value;

    var result = await FlutterBlue.instance._channel
        .invokeMethod('writeCharacteristic', request.writeToBuffer());

    if(type == CharacteristicWriteType.withoutResponse) {
      return result;
    }

    return await FlutterBlue.instance._methodStream
      .where((m) => m.method == "WriteCharacteristicResponse")
      .map((m) => m.arguments)
      .map((List<int> data) => new protos.WriteCharacteristicResponse.fromBuffer(data))
      .where((p) =>
        (p.request.remoteId == request.remoteId) &&
        (p.request.characteristicUuid == request.characteristicUuid) &&
        (p.request.serviceUuid == request.serviceUuid))
      .first
      .then((w) => w.success)
      .then((success) => (!success) ? throw new Exception('Failed to write the characteristic') : null)
      .then((_) => characteristic.value = value)
      .then((_) => null);
  }

  /// Writes the value of a descriptor
  Future<Null> writeDescriptor(BluetoothDescriptor descriptor, List<int> value) async {
    var request = protos.WriteDescriptorRequest.create()
      ..remoteId = id.toString()
      ..descriptorUuid = descriptor.uuid.toString()
      ..characteristicUuid = descriptor.characteristicUuid.toString()
      ..serviceUuid = descriptor.serviceUuid.toString()
      ..value = value;

    await FlutterBlue.instance._channel
        .invokeMethod('writeDescriptor', request.writeToBuffer());

    return await FlutterBlue.instance._methodStream
        .where((m) => m.method == "WriteDescriptorResponse")
        .map((m) => m.arguments)
        .map((List<int> data) => new protos.WriteDescriptorResponse.fromBuffer(data))
        .where((p) =>
        (p.request.remoteId == request.remoteId) &&
        (p.request.descriptorUuid == request.descriptorUuid) &&
        (p.request.characteristicUuid == request.characteristicUuid) &&
        (p.request.serviceUuid == request.serviceUuid))
        .first
        .then((w) => w.success)
        .then((success) => (!success) ? throw new Exception('Failed to write the descriptor') : null)
        .then((_) => descriptor.value = value)
        .then((_) => null);
  }

  /// Sets notifications or indications for the value of a specified characteristic
  Future<bool> setNotifyValue(
      BluetoothCharacteristic characteristic, bool notify) {
    var request = protos.SetNotificationRequest.create()
      ..remoteId = id.toString()
      ..serviceUuid = characteristic.serviceUuid.toString()
      ..characteristicUuid = characteristic.uuid.toString()
      ..enable = notify;
    return FlutterBlue.instance._channel.invokeMethod('setNotification', request.writeToBuffer())
        .then((List<int> data) => new protos.BluetoothCharacteristic.fromBuffer(data))
        .then((p) => new BluetoothCharacteristic.fromProto(p))
        .then((c) {
          characteristic.updateDescriptors(c.descriptors);
          characteristic.value = c.value;
          return (c.isNotifying == notify);
        });
  }

  /// Notifies when the Bluetooth Characteristic's value has changed.
  /// setNotification() should be run first to enable them on the peripheral
  Stream<List<int>> onValueChanged(BluetoothCharacteristic characteristic) {
    return FlutterBlue.instance._characteristicNotifiedChannel
        .receiveBroadcastStream()
        .map((List<int> data) => new protos.OnNotificationResponse.fromBuffer(data))
        .where((p) => p.remoteId == id.toString())
        .map((p) => new BluetoothCharacteristic.fromProto(p.characteristic))
        .where((c) => c.uuid == characteristic.uuid)
        .map((c) {
          characteristic.updateDescriptors(c.descriptors);
          characteristic.value = c.value;
          return c.value;
        });
  }

  /// The current connection state of the peripheral
  Future<BluetoothDeviceState> get state =>
      new Future.error(new UnimplementedError());

  /// Notifies when the Bluetooth Device connection state has changed
  Stream<BluetoothDeviceState> onStateChanged() =>
      new Future.error(new UnimplementedError()).asStream();

  /// Indicates whether the Bluetooth Device can send a write without response
  Future<bool> get canSendWriteWithoutResponse =>
      new Future.error(new UnimplementedError());
}

enum BluetoothDeviceType { unknown, classic, le, dual }

enum CharacteristicWriteType { withResponse, withoutResponse }

enum BluetoothDeviceState { disconnected, connecting, connected, disconnecting }