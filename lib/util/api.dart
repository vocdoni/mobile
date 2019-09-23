import 'package:dvote/util/parsers.dart';
import 'package:vocdoni/controllers/process.dart';
import 'package:vocdoni/util/singletons.dart';
import 'package:dvote/dvote.dart';
import 'package:flutter/foundation.dart'; // for kReleaseMode

// ////////////////////////////////////////////////////////////////////////////
// METHODS
// ////////////////////////////////////////////////////////////////////////////

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
  if (!(entityReference is EntityReference)) return null;

  try {
    final gwInfo = selectRandomGatewayInfo();

    final DVoteGateway dvoteGw =
        DVoteGateway(gwInfo.dvote, publicKey: gwInfo.publicKey);
    final Web3Gateway web3Gw = Web3Gateway(gwInfo.web3);

    EntityMetadata entityMetadata =
        await fetchEntity(entityReference, dvoteGw, web3Gw);
    entityMetadata.meta[META_ENTITY_ID] = entityReference.entityId;

    return entityMetadata;
  } catch (err) {
    if (!kReleaseMode) print(err);
    throw FetchError("The entity's data cannot be fetched");
  }
}

Future<List<ProcessMetadata>> fetchProcessess(
    EntityReference entityReference, EntityMetadata entityMetadata) async {
  try {
    final gwInfo = selectRandomGatewayInfo();

    final DVoteGateway dvoteGw =
        DVoteGateway(gwInfo.dvote, publicKey: gwInfo.publicKey);
    final Web3Gateway web3Gw = Web3Gateway(gwInfo.web3);

    List<ProcessMetadata> activeProcessess = await getProcessesMetadata(
        entityMetadata.votingProcesses.active, dvoteGw, web3Gw);

    for (int i = 0; i < activeProcessess.length; i++) {
     String activeProcess = activeProcessess[i].meta[META_PROCESS_ID];
      activeProcessess[i].meta[META_PROCESS_ID] =
          entityMetadata.votingProcesses.active[i];
      activeProcessess[i].meta[META_ENTITY_ID] = entityReference.entityId;
      activeProcessess[i].meta[META_PROCESS_CENSUS_STATE] = CensusState.UNKNOWN.toString(); 
    }

    return activeProcessess;
  } catch (err) {
  
    throw FetchError("Unable to fetch active processess");
  }
}

Future<Feed> fetchEntityNewsFeed(EntityReference entityReference,
    EntityMetadata entityMetadata, String lang) async {
  // Attempt for every node available
  if (!(entityMetadata is EntityMetadata))
    return null;
  else if (!(entityMetadata.newsFeed is Map<String, String>))
    return null;
  else if (!(entityMetadata.newsFeed[lang] is String)) return null;

  final gw = selectRandomGatewayInfo();

  final String contentUri = entityMetadata.newsFeed[lang];

  // Attempt for every node available
  try {
    ContentURI cUri = ContentURI(contentUri);
    DVoteGateway gateway = DVoteGateway(gw.dvote);
    final result = await fetchFileString(cUri, gateway);
    Feed feed = parseFeed(result);
    feed.meta[META_ENTITY_ID] = entityReference.entityId;
    feed.meta[META_LANGUAGE] = lang;
    return feed;
  } catch (err) {
    print(err);
    throw FetchError("The news feed cannot be fetched");
  }
}

// ////////////////////////////////////////////////////////////////////////////
// UTILITIES
// ////////////////////////////////////////////////////////////////////////////

class FetchError implements Exception {
  final String msg;
  const FetchError(this.msg);
  String toString() => 'FetchError: $msg';
}

GatewayInfo selectRandomGatewayInfo() {
  if (appStateBloc.value == null || appStateBloc.value.bootnodes == null)
    return null;

  final gw = GatewayInfo();

  if (kReleaseMode) {
    // PROD
    int dvoteIdx =
        random.nextInt(appStateBloc.value.bootnodes.homestead.dvote.length);
    int web3Idx =
        random.nextInt(appStateBloc.value.bootnodes.homestead.web3.length);

    gw.dvote = appStateBloc.value.bootnodes.homestead.dvote[dvoteIdx].uri;
    gw.publicKey =
        appStateBloc.value.bootnodes.homestead.dvote[dvoteIdx].pubKey;
    gw.supportedApis
        .addAll(appStateBloc.value.bootnodes.homestead.dvote[dvoteIdx].apis);
    gw.web3 = appStateBloc.value.bootnodes.homestead.web3[web3Idx].uri;
  } else {
    int dvoteIdx =
        random.nextInt(appStateBloc.value.bootnodes.goerli.dvote.length);
    int web3Idx =
        random.nextInt(appStateBloc.value.bootnodes.goerli.web3.length);

    gw.dvote = appStateBloc.value.bootnodes.goerli.dvote[dvoteIdx].uri;
    gw.publicKey = appStateBloc.value.bootnodes.goerli.dvote[dvoteIdx].pubKey;
    gw.supportedApis
        .addAll(appStateBloc.value.bootnodes.goerli.dvote[dvoteIdx].apis);
    gw.web3 = appStateBloc.value.bootnodes.goerli.web3[web3Idx].uri;
  }
  return gw;
}
