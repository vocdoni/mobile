import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vocdoni/util/singletons.dart';
import 'package:vocdoni/constants/settings.dart' show bootnodesUrl;
import 'package:dvote/dvote.dart';

// ////////////////////////////////////////////////////////////////////////////
// METHODS
// ////////////////////////////////////////////////////////////////////////////

Future<List<GatewayInfo>> getBootNodes() async {
  try {
    List<GatewayInfo> result = List<GatewayInfo>();
    final strBootnodes = await http.read(bootnodesUrl);
    Map<String, dynamic> networkItems = jsonDecode(strBootnodes);
    networkItems.forEach((networkId, network) {
      if (!(network is List)) return;
      network.forEach((item) {
        if (!(item is Map)) return;
        GatewayInfo gw = GatewayInfo();
        gw.dvote = item["dvote"] ?? "";
        gw.web3 = item["web3"] ?? "";
        gw.publicKey = item["pubKey"] ?? "";
        gw.meta.addAll({"networkId": networkId ?? ""});
        result.add(gw);
      });
    });
    return result;
  } catch (err) {
    throw FetchError("The boot nodes cannot be loaded");
  }
}

Future<String> makeMnemonic() {
  return generateMnemonic(size: 192);
}

Future<String> privateKeyFromMnemonic(String mnemonic) {
  return mnemonicToPrivateKey(mnemonic);
}

Future<String> publicKeyFromMnemonic(String mnemonic) {
  return mnemonicToPublicKey(mnemonic);
}

Future<String> addressFromMnemonic(String mnemonic) {
  return mnemonicToAddress(mnemonic);
}

Future<EntityMetadata> fetchEntityData(EntityReference entityReference) async {
  // Create a random cloned list
  //TODO: Only used gateways with the currently selected networkId
  //gw.meta["networkId"] == currentlySelecctedNetworkId
  List<GatewayInfo> bootnodes = appStateBloc.value.bootnodes
      .where((gw) => true)
      .toList();
  bootnodes.shuffle();
  

//TODO: Currently not using entrypoints
  // Attempt for every node available
  for (GatewayInfo node in bootnodes) {
    try {
      final EntityMetadata entity = await fetchEntity(entityReference,
           node.dvote, node.web3);

      return entity;
    } catch (err) {
      print(err);
      continue;
    }
  }
  throw FetchError("The entity's data cannot be fetched");
}

Future<String> fetchEntityNewsFeed(EntityMetadata entityMetadata, String lang) async {
  // Attempt for every node available
  if (!(entityMetadata is EntityMetadata))
    return null;
  else if (!(entityMetadata.newsFeed is Map<String, String>))
    return null;
  else if (!(entityMetadata.newsFeed[lang] is String)) return null;

  // Create a random cloned list
  var bootnodes = appStateBloc.value.bootnodes.skip(0).toList();
  bootnodes.shuffle();

  final String contentUri = entityMetadata.newsFeed[lang];

  // Attempt for every node available
  for (GatewayInfo node in bootnodes) {
    try {
      ContentURI cUri = ContentURI(contentUri);
      final result = await fetchFileString(cUri, node.dvote);
      return result;
    } catch (err) {
      print(err);
      continue;
    }
  }
  throw FetchError("The news feed cannot be fetched");
}

// ////////////////////////////////////////////////////////////////////////////
// UTILITIES
// ////////////////////////////////////////////////////////////////////////////

class FetchError implements Exception {
  final String msg;
  const FetchError(this.msg);
  String toString() => 'FetchError: $msg';
}
