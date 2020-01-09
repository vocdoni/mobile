import 'dart:io';
import 'package:dvote/dvote.dart';
import 'package:flutter/foundation.dart';
import 'package:vocdoni/lib/errors.dart';
import "package:vocdoni/data-persistence/base-persistence.dart";
import "package:vocdoni/constants/storage-names.dart";

final String _storageFile = BOOTNODES_STORE_FILE;

class BootnodesPersistence
    extends BasePersistenceSingle<BootNodeGateways> {
  @override
  Future<BootNodeGateways> read() async {
    await super.init();

    try {
      final File fd = File("${storageDir.path}/$_storageFile");
      if (!(await fd.exists())) {
        final emptyValue = BootNodeGateways();
        set(emptyValue);
        return emptyValue;
      }

      final bytes = await fd.readAsBytes();
      final BootNodeGateways gwList = BootNodeGateways.fromBuffer(bytes);

      // Update the in-memory current value
      set(gwList);

      return gwList;
    } catch (err) {
      if (!kReleaseMode) print(err);
      throw RestoreError("There was an error while reading the local data");
    }
  }

  @override
  Future<void> write(BootNodeGateways value) async {
    await super.init();

    try {
      File fd = File("${storageDir.path}/$_storageFile");
      await fd.writeAsBytes(value.writeToBuffer());

      // Update the in-memory current value
      set(value);
    } catch (err) {
      print(err);
      throw PersistError("There was an error while storing the changes");
    }
  }
}
